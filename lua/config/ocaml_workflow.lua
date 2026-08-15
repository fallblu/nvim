local M = {}

local ocaml = require("config.ocaml")
local ocaml_cache = require("config.ocaml_cache")
local ocaml_output = require("config.ocaml_output")
local uv = vim.uv or vim.loop

local terminal_window = { position = "bottom", height = 0.4 }
local repl_window = { position = "bottom", height = 0.4 }
local async_jobs = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "OCaml" })
end

local function current_path(buffer)
  return vim.api.nvim_buf_get_name(buffer or 0)
end

local function dune_root(buffer)
  local path = current_path(buffer)
  local root = ocaml.root(path)
  if not ocaml.is_dune_project(root) then
    notify("No dune-project or dune-workspace found", vim.log.levels.WARN)
    return nil
  end
  return root
end

local function tool_available(tool, root)
  local available, location = ocaml.tool_available(tool, root)
  if available then
    return true
  end

  notify(
    ("%s is unavailable in %s; install it with `opam install %s`"):format(tool, location, tool),
    vim.log.levels.ERROR
  )
  return false
end

local function channel_running(channel)
  if not channel or channel <= 0 then
    return false
  end
  local ok, status = pcall(vim.fn.jobwait, { channel }, 0)
  return ok and status[1] == -1
end

local function stop_terminal_job(terminal, cleanup_rpc)
  local channel = terminal.ocaml_channel or (terminal:buf_valid() and vim.bo[terminal.buf].channel or nil)
  terminal.ocaml_stopping = true
  if not channel_running(channel) then
    if cleanup_rpc then
      ocaml_cache.cleanup_rpc_registry()
    end
    return
  end

  -- jobstop sends SIGTERM through Neovim's job controller and closes the PTY.
  -- Unlike a raw PID signal, it also accounts for the process attached to the
  -- terminal channel and lets buffer deletion complete synchronously.
  pcall(vim.fn.jobstop, channel)
  vim.defer_fn(function()
    if cleanup_rpc then
      ocaml_cache.cleanup_rpc_registry()
    end
  end, 100)
end

local function attach_terminal_lifecycle(terminal, cleanup_rpc)
  terminal:on("TermOpen", function()
    terminal.ocaml_channel = vim.bo[terminal.buf].channel
    terminal.ocaml_stopping = false
  end, { buf = true })
  terminal:on("TermClose", function()
    terminal.ocaml_channel = nil
    if cleanup_rpc then
      vim.schedule(ocaml_cache.cleanup_rpc_registry)
    end
  end, { buf = true })
  terminal:on("BufUnload", function()
    stop_terminal_job(terminal, cleanup_rpc)
  end, { buf = true })
end

local function run_async(key, command, opts, callback)
  local previous = async_jobs[key]
  if previous then
    pcall(previous.kill, previous, 15)
  end

  local process
  process = vim.system(command, opts, function(result)
    vim.schedule(function()
      if async_jobs[key] ~= process then
        return
      end
      async_jobs[key] = nil
      callback(result)
    end)
  end)
  async_jobs[key] = process
end

local function open_terminal(command, root, persistent, window)
  require("snacks").terminal(command, {
    cwd = root,
    auto_close = not persistent,
    win = window or terminal_window,
  })
end

local function run_dune(arguments, persistent, window, root)
  root = root or dune_root()
  if not root or not tool_available("dune", root) then
    return
  end
  open_terminal(ocaml.opam_command("dune", arguments, root), root, persistent, window)
end

function M.build(arguments)
  local args = { "build" }
  vim.list_extend(args, arguments or {})
  run_dune(args, false)
end

function M.watch()
  local root = dune_root()
  if not root then
    return
  end
  local build_dir = ocaml_cache.build_dir("ocaml-watch", root)
  run_dune({ "build", "--watch", "--build-dir", build_dir }, true, {
    position = terminal_window.position,
    height = terminal_window.height,
    on_buf = function(terminal)
      attach_terminal_lifecycle(terminal, true)
    end,
    keys = {
      hide_watch = {
        "<localleader>w",
        "hide",
        mode = { "n", "t" },
        desc = "Hide Dune build watch",
      },
    },
  }, root)
end

function M.test(arguments)
  local args = { "runtest" }
  vim.list_extend(args, arguments or {})
  run_dune(args, false)
end

local function execute_words(words)
  if not words or not words[1] then
    return
  end

  local args = { "exec", words[1] }
  if #words > 1 then
    args[#args + 1] = "--"
    vim.list_extend(args, vim.list_slice(words, 2))
  end
  run_dune(args, false)
end

function M.execute(words)
  if words and #words > 0 then
    execute_words(words)
    return
  end

  vim.ui.input({ prompt = "Dune executable and arguments: " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    execute_words(vim.fn.shellsplit(input))
  end)
end

function M.docs()
  local root = dune_root()
  if not root or not tool_available("dune", root) or not tool_available("odoc", root) then
    return
  end

  notify("Building OCaml documentation…")
  run_async(
    "docs:" .. root,
    ocaml.opam_command("dune", { "build", "@doc" }, root),
    { cwd = root, text = true },
    function(result)
      local output = (result.stdout or "") .. (result.stderr or "")
      if result.code ~= 0 then
        vim.fn.setqflist({}, " ", {
          title = "Dune documentation",
          items = ocaml_output.parse_dune(output, root),
        })
        vim.cmd.copen()
        notify("Documentation build failed", vim.log.levels.ERROR)
        return
      end

      local index = vim.fs.joinpath(root, "_build", "default", "_doc", "_html", "index.html")
      if not uv.fs_stat(index) then
        notify("Documentation built, but its index was not found", vim.log.levels.WARN)
        return
      end

      vim.ui.select({ "Open documentation", "Not now" }, { prompt = "Documentation built" }, function(choice)
        if choice == "Open documentation" then
          local _, err = vim.ui.open(index)
          if err then
            notify(err, vim.log.levels.ERROR)
          end
        end
      end)
    end
  )
end

local function repl_spec(buffer)
  local root = ocaml.root(current_path(buffer))
  local command
  if ocaml.is_dune_project(root) then
    local build_dir = ocaml_cache.build_dir("ocaml-utop", root)
    command = ocaml.opam_command("dune", { "utop", "--build-dir", build_dir }, root)
  else
    command = ocaml.opam_command("utop", nil, root)
  end
  return command,
    {
      cwd = root,
      interactive = false,
      auto_insert = true,
      auto_close = false,
      win = vim.tbl_deep_extend("force", {}, repl_window, {
        keys = {
          hide_repl = {
            "<localleader>r",
            "hide",
            mode = { "n", "t" },
            desc = "Hide UTop",
          },
        },
        on_buf = function(terminal)
          attach_terminal_lifecycle(terminal, false)
          terminal:on("TermClose", function()
            if terminal.ocaml_stopping then
              return
            end
            if vim.v.event.status == 0 then
              terminal:close()
              vim.cmd.checktime()
            else
              local status = vim.v.event.status
              vim.schedule(function()
                if terminal:buf_valid() and not terminal.ocaml_stopping then
                  notify(("UTop exited with code %d; check the terminal output"):format(status), vim.log.levels.ERROR)
                end
              end)
            end
          end, { buf = true })
        end,
      }),
    },
    root
end

local function repl_running(terminal)
  if not terminal or not terminal:buf_valid() then
    return false
  end
  local channel = vim.bo[terminal.buf].channel
  return channel_running(channel)
end

local function get_repl(buffer, create)
  local command, opts, root = repl_spec(buffer)
  if not tool_available("utop", root) then
    return nil
  end
  if ocaml.is_dune_project(root) and not tool_available("dune", root) then
    return nil
  end

  opts.create = create
  local terminal, created = require("snacks").terminal.get(command, opts)
  if terminal and not created and not repl_running(terminal) then
    terminal:close()
    terminal = nil
  end
  if not terminal and create then
    terminal, created = require("snacks").terminal.get(command, opts)
  end
  return terminal, created
end

function M.toggle_repl()
  local buffer = vim.api.nvim_get_current_buf()
  local terminal, created = get_repl(buffer, true)
  if not terminal then
    return
  end

  if not created and vim.api.nvim_get_current_buf() == terminal.buf then
    terminal:hide()
    return
  end
  terminal:show():focus()
  vim.cmd.startinsert()
end

local function send_to_repl(text, buffer)
  text = text or ""
  if text:match("^%s*$") then
    notify("There is no OCaml text to send", vim.log.levels.WARN)
    return
  end

  local trailing = text:match("%s*$") or ""
  local body = trailing == "" and text or text:sub(1, #text - #trailing)
  if not body:match(";;$") then
    body = body .. ";;"
  end
  text = body .. trailing

  buffer = buffer or vim.api.nvim_get_current_buf()
  local source_window = vim.api.nvim_get_current_win()
  local terminal = get_repl(buffer, true)
  if not terminal then
    return
  end

  terminal:show()
  if vim.api.nvim_win_is_valid(source_window) then
    vim.api.nvim_set_current_win(source_window)
  end

  local function send(attempt)
    if not terminal:buf_valid() then
      notify("UTop closed before the text could be sent", vim.log.levels.ERROR)
      return
    end

    local channel = vim.bo[terminal.buf].channel
    if channel_running(channel) then
      vim.api.nvim_chan_send(channel, text .. "\n")
      return
    end
    if attempt >= 50 then
      notify("UTop did not start in time", vim.log.levels.ERROR)
      return
    end
    vim.defer_fn(function()
      send(attempt + 1)
    end, 20)
  end
  send(0)
end

function M.send_line()
  send_to_repl(vim.api.nvim_get_current_line())
end

function M.send_selection()
  local mode = vim.fn.visualmode()
  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = mode })
  send_to_repl(table.concat(lines, "\n"))
end

function M.send_phrase()
  local buffer = vim.api.nvim_get_current_buf()
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buffer })
  if not ok or not node then
    notify("No OCaml syntax node found at the cursor", vim.log.levels.WARN)
    return
  end

  local parent = node:parent()
  while parent and parent:parent() do
    node = parent
    parent = node:parent()
  end
  if not parent then
    notify("Place the cursor inside an OCaml phrase", vim.log.levels.WARN)
    return
  end

  send_to_repl(vim.treesitter.get_node_text(node, buffer), buffer)
end

function M.send_file()
  local buffer = vim.api.nvim_get_current_buf()
  local path = current_path(buffer)
  if path == "" then
    notify("Save the OCaml buffer before sending it", vim.log.levels.WARN)
    return
  end
  if vim.bo[buffer].modified then
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd.write()
    end)
  end

  local escaped = path:gsub("\\", "\\\\"):gsub('"', '\\"')
  send_to_repl(('#use "%s"'):format(escaped), buffer)
end

function M.switch_impl_intf()
  if vim.fn.exists(":LspOcamllspSwitchImplIntf") == 2 then
    vim.cmd.LspOcamllspSwitchImplIntf()
  else
    notify("ocamllsp is not attached yet", vim.log.levels.WARN)
  end
end

function M.refresh_tools()
  ocaml.clear_tool_cache()
  require("config.ocaml_indent").clear_cache()
  notify("Cleared cached OPAM tool resolutions")
end

---@param all? boolean
function M.clean_cache(all)
  local root = ocaml.root(current_path())

  local function clean()
    local removed, errors = ocaml_cache.clean(root, all == true)
    if #errors > 0 then
      notify(table.concat(errors, "\n"), vim.log.levels.ERROR)
      return
    end
    notify(("Removed %d OCaml cache director%s"):format(removed, removed == 1 and "y" or "ies"))
  end

  if all then
    clean()
    return
  end

  vim.ui.select({ "Remove project caches", "Cancel" }, {
    prompt = "Close this project's Dune watch and UTop before cleaning",
  }, function(choice)
    if choice == "Remove project caches" then
      clean()
    end
  end)
end

function M.actions()
  local actions = {
    { label = "Build project", run = M.build },
    { label = "Toggle build watch", run = M.watch },
    { label = "Run tests", run = M.test },
    { label = "Run executable", run = M.execute },
    { label = "Build documentation", run = M.docs },
    { label = "Toggle UTop", run = M.toggle_repl },
    { label = "Send current phrase", run = M.send_phrase },
    { label = "Send current line", run = M.send_line },
    { label = "Send current file", run = M.send_file },
    { label = "Switch implementation/interface", run = M.switch_impl_intf },
    { label = "Refresh OPAM tools", run = M.refresh_tools },
    { label = "Clean project caches", run = M.clean_cache },
  }

  require("snacks").picker.select(actions, {
    prompt = "OCaml actions",
    format_item = function(action)
      return action.label
    end,
  }, function(action)
    if action then
      action.run()
    end
  end)
end

local function map_buffer(buffer)
  if vim.b[buffer].ocaml_workflow_configured then
    return
  end
  vim.b[buffer].ocaml_workflow_configured = true

  local function map(mode, lhs, rhs, description)
    vim.keymap.set(mode, lhs, rhs, { buffer = buffer, silent = true, desc = "OCaml: " .. description })
  end

  map("n", "<localleader>a", M.actions, "pick action")
  map("n", "<localleader>b", M.build, "build")
  map("n", "<localleader>w", M.watch, "toggle build watch")
  map("n", "<localleader>t", M.test, "run tests")
  map("n", "<localleader>x", M.execute, "run executable")
  map("n", "<localleader>d", M.docs, "build documentation")

  if vim.tbl_contains(ocaml.source_filetypes, vim.bo[buffer].filetype) then
    map("n", "<localleader>r", M.toggle_repl, "toggle UTop")
    map("n", "<localleader>s", M.send_phrase, "send phrase")
    map("x", "<localleader>s", M.send_selection, "send selection")
    map("n", "<localleader>l", M.send_line, "send line")
    map("n", "<localleader>f", M.send_file, "send file")
    map("n", "<localleader>i", M.switch_impl_intf, "switch implementation/interface")
  end

  vim.api.nvim_buf_create_user_command(buffer, "OcamlActions", M.actions, { desc = "Search OCaml actions" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlBuild", function(command)
    M.build(command.fargs)
  end, { nargs = "*", complete = "file", desc = "Build the Dune project" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlWatch", M.watch, { desc = "Toggle Dune build watch" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlTest", function(command)
    M.test(command.fargs)
  end, { nargs = "*", complete = "file", desc = "Run Dune tests" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlExec", function(command)
    M.execute(command.fargs)
  end, { nargs = "*", complete = "file", desc = "Run a Dune executable" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlDocs", M.docs, { desc = "Build OCaml documentation" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlUtop", M.toggle_repl, { desc = "Toggle the project UTop" })
  vim.api.nvim_buf_create_user_command(
    buffer,
    "OcamlSendPhrase",
    M.send_phrase,
    { desc = "Send the current phrase to UTop" }
  )
  vim.api.nvim_buf_create_user_command(buffer, "OcamlSendLine", M.send_line, { desc = "Send the current line to UTop" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlSendFile", M.send_file, { desc = "Send the current file to UTop" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlSwitchImplIntf", M.switch_impl_intf, {
    desc = "Switch between the OCaml implementation and interface",
  })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlRefreshTools", M.refresh_tools, {
    desc = "Refresh cached OPAM tool resolutions",
  })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlCleanCache", function(command)
    M.clean_cache(command.bang)
  end, {
    bang = true,
    desc = "Clean project OCaml caches; use ! to clean all OCaml caches",
  })

  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.add({ { "<localleader>", group = "OCaml", buffer = buffer } })
  end
end

function M.setup()
  ocaml_cache.cleanup_rpc_registry()
  local group = vim.api.nvim_create_augroup("garrett_ocaml_workflow", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = ocaml.filetypes,
    callback = function(event)
      map_buffer(event.buf)
    end,
  })
end

return M
