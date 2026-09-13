local M = {}

-- Use the current file's project, even when Neovim was launched elsewhere.
-- Terminals remember the root from which they were created.
function M.root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.b[bufnr].terminal_project_root or vim.fs.root(bufnr, { "pyproject.toml", ".git" }) or vim.fn.getcwd()
end

-- Prefer the tool version installed by uv in this project.
function M.executable(name, root)
	local path = vim.fs.joinpath(root or M.root(), ".venv", "bin", name)
	return vim.fn.executable(path) == 1 and path or name
end

function M.python(root)
	local path = vim.fs.joinpath(root or M.root(), ".venv", "bin", "python")
	if vim.fn.executable(path) == 1 then
		return path
	end
	vim.notify("No project .venv/bin/python. Prepare this project's uv environment first.", vim.log.levels.WARN)
end

return M
