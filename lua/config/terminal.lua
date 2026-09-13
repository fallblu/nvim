local project = require("config.project")
local M = {}

-- Shared by ordinary shells, Python, and pytest. Commands are argument lists.
function M.run(command, root, opts)
	opts = opts or {}
	local win = opts.reuse and vim.fn.bufwinid(opts.reuse) or -1
	if win ~= -1 then
		vim.api.nvim_set_current_win(win)
		vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
	else
		vim.cmd(opts.vertical and "botright vnew" or "botright 12new")
	end
	vim.b.terminal_project_root = root
	local buf = vim.api.nvim_get_current_buf()
	local job = vim.fn.jobstart(command, { term = true, cwd = root })
	if job <= 0 then
		vim.notify("Could not start " .. command[1], vim.log.levels.ERROR)
		return
	end
	vim.opt_local.number = false
	vim.opt_local.relativenumber = false
	vim.opt_local.signcolumn = "no"
	if opts.insert ~= false then
		vim.cmd.startinsert()
	end
	return { buf = buf, job = job }
end

vim.keymap.set("n", "<leader>tt", function()
	M.run({ vim.o.shell }, project.root())
end, { desc = "New project terminal below" })
vim.keymap.set("n", "<leader>tv", function()
	M.run({ vim.o.shell }, project.root(), { vertical = true })
end, { desc = "New project terminal to the right" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Enter Terminal-Normal mode" })

return M
