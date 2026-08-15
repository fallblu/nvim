local M = {}

local uv = vim.uv or vim.loop
local namespaces = { "ocaml-watch", "ocaml-utop" }

---@param name string
---@return string
local function namespace_dir(name)
  return vim.fs.joinpath(vim.fn.stdpath("cache"), name)
end

---@param root string
---@return string
local function project_key(root)
  return vim.fn.sha256(vim.fs.normalize(root)):sub(1, 16)
end

---@param name string
---@param root string
---@return string
function M.build_dir(name, root)
  local cache = namespace_dir(name)
  vim.fn.mkdir(cache, "p")
  return vim.fs.joinpath(cache, project_key(root))
end

---@param root string
---@return string[]
function M.project_dirs(root)
  local key = project_key(root)
  return vim.tbl_map(function(name)
    return vim.fs.joinpath(namespace_dir(name), key)
  end, namespaces)
end

local function process_alive(pid)
  return pid ~= nil and uv.kill(pid, 0) == 0
end

---@return integer
function M.cleanup_rpc_registry()
  local runtime = vim.env.XDG_RUNTIME_DIR
  if not runtime or runtime == "" then
    return 0
  end

  local registry = vim.fs.joinpath(runtime, "dune", "rpc")
  if not uv.fs_stat(registry) then
    return 0
  end

  local owned_prefix = vim.fs.normalize(namespace_dir("ocaml-watch")) .. "/"
  local entries = {}
  local live_sockets = {}

  for name, kind in vim.fs.dir(registry) do
    if kind == "file" and name:match("%.csexp$") then
      local path = vim.fs.joinpath(registry, name)
      local ok, lines = pcall(vim.fn.readfile, path, "", 10)
      local content = ok and table.concat(lines, "") or ""
      local pid = tonumber(content:match("%(3:pid%d+:(%d+)%)"))
      local socket = content:match("unix:path=([^%)]+)")
      socket = socket and vim.fs.normalize(socket) or nil
      if socket and socket:sub(1, #owned_prefix) == owned_prefix then
        local alive = process_alive(pid)
        entries[#entries + 1] = { path = path, socket = socket, alive = alive }
        if alive then
          live_sockets[socket] = true
        end
      end
    end
  end

  local removed = 0
  for _, entry in ipairs(entries) do
    if not entry.alive then
      if uv.fs_unlink(entry.path) then
        removed = removed + 1
      end
      if not live_sockets[entry.socket] and uv.fs_stat(entry.socket) then
        pcall(uv.fs_unlink, entry.socket)
      end
    end
  end
  return removed
end

local function safe_cache_target(path)
  path = vim.fs.normalize(path)
  for _, name in ipairs(namespaces) do
    local namespace = vim.fs.normalize(namespace_dir(name))
    if path == namespace or path:sub(1, #namespace + 1) == namespace .. "/" then
      return true
    end
  end
  return false
end

---@param root string
---@param all boolean
---@return integer
---@return string[]
function M.clean(root, all)
  M.cleanup_rpc_registry()
  local targets = all and vim.tbl_map(namespace_dir, namespaces) or M.project_dirs(root)
  local removed = 0
  local errors = {}

  for _, path in ipairs(targets) do
    if safe_cache_target(path) and uv.fs_stat(path) then
      local ok, err = pcall(vim.fs.rm, path, { recursive = true })
      if ok then
        removed = removed + 1
      else
        errors[#errors + 1] = tostring(err)
      end
    end
  end

  return removed, errors
end

return M
