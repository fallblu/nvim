local M = {}

local ocaml = require("config.ocaml")

local terminal_window = { position = "bottom", height = 0.4 }

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
  local result = vim.system(ocaml.opam_command("which", { tool }, root), { cwd = root, text = true }):wait(3000)
  if result.code == 0 then
    return true
  end

  local switch = ocaml.local_switch(root)
  local location = switch and ("the local switch at " .. switch) or "the active OPAM switch"
  notify(
    ("%s is unavailable in %s; install it with `opam install %s`"):format(tool, location, tool),
    vim.log.levels.ERROR
  )
  return false
end

local function open_terminal(command, root, persistent, window)
  require("snacks").terminal(command, {
    cwd = root,
    auto_close = not persistent,
    win = window or terminal_window,
  })
end

local function run_dune(arguments, persistent, window)
  local root = dune_root()
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
  run_dune({ "build", "--watch" }, true, {
    position = terminal_window.position,
    height = terminal_window.height,
    keys = {
      hide_watch = {
        "<localleader>w",
        "hide",
        mode = { "n", "t" },
        desc = "Hide Dune build watch",
      },
    },
  })
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
  vim.system(ocaml.opam_command("dune", { "build", "@doc" }, root), { cwd = root, text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or "") .. (result.stderr or "")
      if result.code ~= 0 then
        vim.fn.setqflist({}, " ", {
          title = "Dune documentation",
          lines = vim.split(output, "\n", { trimempty = true }),
        })
        vim.cmd.copen()
        notify("Documentation build failed", vim.log.levels.ERROR)
        return
      end

      local index = vim.fs.joinpath(root, "_build", "default", "_doc", "_html", "index.html")
      if not (vim.uv or vim.loop).fs_stat(index) then
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
    end)
  end)
end

local function repl_spec(buffer)
  local root = ocaml.root(current_path(buffer))
  local command
  if ocaml.is_dune_project(root) then
    command = ocaml.opam_command("dune", { "utop" }, root)
  else
    command = ocaml.opam_command("utop", nil, root)
  end
  return command,
    {
      cwd = root,
      interactive = false,
      auto_close = false,
      win = terminal_window,
    },
    root
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
  local terminal = require("snacks").terminal.get(command, opts)
  return terminal
end

function M.toggle_repl()
  local buffer = vim.api.nvim_get_current_buf()
  local command, opts, root = repl_spec(buffer)
  if not tool_available("utop", root) or (ocaml.is_dune_project(root) and not tool_available("dune", root)) then
    return
  end

  local terminal = require("snacks").terminal.focus(command, opts)
  if terminal and vim.api.nvim_get_current_buf() == terminal.buf then
    vim.cmd.startinsert()
  end
end

local function send_to_repl(text, buffer)
  text = vim.trim(text or "")
  if text == "" then
    notify("There is no OCaml text to send", vim.log.levels.WARN)
    return
  end
  if not text:match(";;%s*$") then
    text = text .. ";;"
  end

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

  local ready = vim.wait(1000, function()
    return vim.api.nvim_buf_is_valid(terminal.buf) and vim.bo[terminal.buf].channel > 0
  end, 20)
  if not ready then
    notify("UTop did not start in time", vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_chan_send(vim.bo[terminal.buf].channel, text .. "\n")
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
  end, { nargs = "*", desc = "Build the Dune project" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlWatch", M.watch, { desc = "Toggle Dune build watch" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlTest", function(command)
    M.test(command.fargs)
  end, { nargs = "*", desc = "Run Dune tests" })
  vim.api.nvim_buf_create_user_command(buffer, "OcamlExec", function(command)
    M.execute(command.fargs)
  end, { nargs = "*", desc = "Run a Dune executable" })
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

  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.add({ { "<localleader>", group = "OCaml", buffer = buffer } })
  end
end

function M.setup()
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
