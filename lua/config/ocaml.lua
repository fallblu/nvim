local M = {}

local uv = vim.uv or vim.loop
local tool_cache = {}

M.filetypes = { "ocaml", "ocamlinterface", "ocamllex", "menhir", "dune" }
M.source_filetypes = { "ocaml", "ocamlinterface", "ocamllex", "menhir" }

local function directory(path)
  path = path and path ~= "" and vim.fs.normalize(path) or uv.cwd() or "."
  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return path
  end
  return vim.fs.dirname(path) or uv.cwd() or "."
end

local function find_upward(names, path, kind)
  return vim.fs.find(names, {
    path = directory(path),
    upward = true,
    type = kind,
  })[1]
end

---@param path? string
---@return string
function M.root(path)
  path = path or vim.api.nvim_buf_get_name(0)
  local start = directory(path)
  local marker = find_upward(function(name)
    return name == "dune-project" or name == "dune-workspace" or name == ".git" or name:match("%.opam$") ~= nil
  end, start)
  return marker and vim.fs.dirname(marker) or start
end

---@param path? string
---@return string?
function M.local_switch(path)
  local root = M.root(path)
  local switch = vim.fs.joinpath(root, "_opam")
  local config = vim.fs.joinpath(switch, ".opam-switch", "switch-config")
  return uv.fs_stat(config) and root or nil
end

---@param tool string
---@param path? string
---@return string[]
function M.opam_prefix(tool, path)
  local args = { "exec" }
  local switch = M.local_switch(path)
  if switch then
    args[#args + 1] = "--switch=" .. switch
  end
  vim.list_extend(args, { "--", tool })
  return args
end

---@param tool string
---@param args? string[]
---@param path? string
---@return string[]
function M.opam_command(tool, args, path)
  local command = { "opam" }
  vim.list_extend(command, M.opam_prefix(tool, path))
  vim.list_extend(command, args or {})
  return command
end

---@param path? string
---@return boolean
function M.is_dune_project(path)
  local root = M.root(path)
  return uv.fs_stat(vim.fs.joinpath(root, "dune-project")) ~= nil
    or uv.fs_stat(vim.fs.joinpath(root, "dune-workspace")) ~= nil
end

---@param tool string
---@param path? string
---@return boolean
---@return string
function M.tool_available(tool, path)
  local root = M.root(path)
  local switch = M.local_switch(root)
  local cache_key = table.concat({ switch or "active", root, tool }, "\0")
  if tool_cache[cache_key] ~= nil then
    return tool_cache[cache_key], switch and ("the local switch at " .. switch) or "the active OPAM switch"
  end

  if vim.fn.executable("opam") ~= 1 then
    tool_cache[cache_key] = false
    return false, "OPAM"
  end

  local result = vim.system(M.opam_command("which", { tool }, root), { cwd = root, text = true }):wait(3000)
  tool_cache[cache_key] = result.code == 0
  return tool_cache[cache_key], switch and ("the local switch at " .. switch) or "the active OPAM switch"
end

function M.clear_tool_cache()
  tool_cache = {}
end

return M
