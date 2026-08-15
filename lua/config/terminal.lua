local M = {}

local uv = vim.uv or vim.loop

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param bufnr? integer
---@return string
function M.root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if LazyVim and LazyVim.root then
    local root = LazyVim.root({ buf = bufnr, normalize = true })
    if root and root ~= "" then
      return root
    end
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename ~= "" then
    return vim.fs.dirname(vim.fs.normalize(filename))
  end

  return uv.cwd() or "."
end

---@return string?
function M.selected_python()
  local ok, selector = pcall(require, "venv-selector")
  if not ok then
    return nil
  end

  local python = selector.python()
  return python and vim.fn.executable(python) == 1 and python or nil
end

---@param root string
---@return boolean
function M.is_uv_project(root)
  return vim.fn.executable("uv") == 1 and exists(vim.fs.joinpath(root, "uv.lock"))
end

---@param root string
---@return string[]?
function M.python_command(root)
  local selected = M.selected_python()
  if selected then
    return { selected }
  end

  if M.is_uv_project(root) then
    return { "uv", "run", "python" }
  end

  for _, executable in ipairs({ "ipython", "python3", "python" }) do
    if vim.fn.executable(executable) == 1 then
      return { executable }
    end
  end

  return nil
end

---@param root string
---@param args? string[]
---@return string[]?
function M.pytest_command(root, args)
  args = args or {}

  local selected = M.selected_python()
  if selected then
    return vim.list_extend({ selected, "-m", "pytest" }, args)
  end

  if M.is_uv_project(root) then
    return vim.list_extend({ "uv", "run", "pytest" }, args)
  end

  if vim.fn.executable("pytest") == 1 then
    return vim.list_extend({ "pytest" }, args)
  end

  for _, executable in ipairs({ "python3", "python" }) do
    if vim.fn.executable(executable) == 1 then
      return vim.list_extend({ executable, "-m", "pytest" }, args)
    end
  end

  return nil
end

---@param path string
---@return boolean
function M.directory_exists(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

return M
