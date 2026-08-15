local M = {}

local ocaml = require("config.ocaml")
local uv = vim.uv or vim.loop

local cache = {}
local failures = {}
local commands = {}

local filetypes = { "ocaml", "ocamlinterface" }
local indent_keys = {
  "0=and",
  "0=class",
  "0=constraint",
  "0=done",
  "0=else",
  "0=end",
  "0=exception",
  "0=external",
  "0=if",
  "0=in",
  "0=include",
  "0=inherit",
  "0=initializer",
  "0=let",
  "0=method",
  "0=open",
  "0=then",
  "0=type",
  "0=val",
  "0=with",
  "0;;",
  "0|",
}

local function notify_failure(buffer, message)
  if failures[buffer] == message then
    return
  end
  failures[buffer] = message
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buffer) then
      vim.notify(message, vim.log.levels.ERROR, { title = "OCaml indentation" })
    end
  end)
end

local function command_for(buffer)
  local filename = vim.api.nvim_buf_get_name(buffer)
  local root = ocaml.root(filename)
  if commands[root] then
    return vim.deepcopy(commands[root]), root
  end
  local switch = ocaml.local_switch(root)

  if switch then
    local executable = vim.fs.joinpath(switch, "_opam", "bin", "ocp-indent")
    if uv.fs_stat(executable) then
      commands[root] = { executable }
      return vim.deepcopy(commands[root]), root
    end
  end

  commands[root] = ocaml.opam_command("ocp-indent", nil, root)
  return vim.deepcopy(commands[root]), root
end

local function configure_indentkeys(buffer)
  local value = vim.api.nvim_get_option_value("indentkeys", { buf = buffer })
  local existing = {}
  for key in value:gmatch("[^,]+") do
    existing[key] = true
  end

  local keys = value == "" and {} or { value }
  for _, key in ipairs(indent_keys) do
    if not existing[key] then
      keys[#keys + 1] = key
    end
  end
  vim.api.nvim_set_option_value("indentkeys", table.concat(keys, ","), { buf = buffer })
end

---@return integer
function M.get()
  local buffer = vim.api.nvim_get_current_buf()
  local line = vim.v.lnum
  local tick = vim.api.nvim_buf_get_changedtick(buffer)
  local cached = cache[buffer]

  if cached and cached.tick == tick and cached.indents[line] then
    return cached.indents[line]
  end

  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local command, root = command_for(buffer)
  vim.list_extend(command, { "--numeric", "--indent-empty" })

  local result = vim
    .system(command, {
      cwd = root,
      stdin = table.concat(lines, "\n") .. "\n",
      text = true,
    })
    :wait(3000)

  if result.code ~= 0 then
    local detail = vim.trim(result.stderr or "")
    notify_failure(
      buffer,
      detail ~= "" and ("ocp-indent failed: " .. detail)
        or ("ocp-indent exited with code " .. tostring(result.code or "unknown"))
    )
    return -1
  end

  local indents = {}
  for value in (result.stdout or ""):gmatch("[^\r\n]+") do
    indents[#indents + 1] = tonumber(value)
  end

  -- ocp-indent may report one additional empty line when stdin ends in a
  -- newline. Only the values corresponding to actual buffer lines matter.
  if #indents < #lines or not indents[line] then
    notify_failure(buffer, "ocp-indent returned an unexpected indentation result")
    return -1
  end

  cache[buffer] = { tick = tick, indents = indents }
  failures[buffer] = nil
  return indents[line]
end

function M.setup()
  local group = vim.api.nvim_create_augroup("garrett_ocaml_indent", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = filetypes,
    callback = function(event)
      cache[event.buf] = nil
      failures[event.buf] = nil

      vim.bo[event.buf].autoindent = true
      vim.bo[event.buf].cindent = false
      vim.bo[event.buf].expandtab = true
      vim.bo[event.buf].shiftwidth = 2
      vim.bo[event.buf].smartindent = false
      vim.bo[event.buf].softtabstop = 2
      vim.bo[event.buf].indentexpr = "v:lua.require'config.ocaml_indent'.get()"
      configure_indentkeys(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufFilePost", "BufWipeout" }, {
    group = group,
    callback = function(event)
      cache[event.buf] = nil
      failures[event.buf] = nil
      commands = {}
    end,
  })
end

function M.clear_cache()
  cache = {}
  failures = {}
  commands = {}
end

return M
