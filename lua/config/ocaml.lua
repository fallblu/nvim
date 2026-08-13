local M = {}

local uv = vim.uv or vim.loop

M.filetypes = { "ocaml", "ocamlinterface", "ocamllex", "menhir", "dune" }
M.source_filetypes = { "ocaml", "ocamlinterface", "ocamllex", "menhir" }

local function directory(path)
  path = path ~= "" and vim.fs.normalize(path) or uv.cwd()
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory" and path or vim.fs.dirname(path)
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
  local marker = find_upward({ "dune-project", "dune-workspace" }, start, "file")
    or find_upward(function(name)
      return name:match("%.opam$") ~= nil
    end, start, "file")
    or find_upward(".git", start, "directory")
  return marker and vim.fs.dirname(marker) or start
end

---@param path? string
---@return string?
function M.local_switch(path)
  local switch = find_upward("_opam", path or M.root(), "directory")
  if not switch then
    return nil
  end

  local config = vim.fs.joinpath(switch, ".opam-switch", "switch-config")
  return uv.fs_stat(config) and vim.fs.dirname(switch) or nil
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
  return find_upward({ "dune-project", "dune-workspace" }, path or M.root(), "file") ~= nil
end

return M
