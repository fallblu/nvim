local project = require("config.project")
local terminal = require("config.terminal")
local M = {}
local last_tests, test_terms, repls = {}, {}, {}

vim.g["test#enabled_runners"] = { "python#pytest" }
vim.g["test#python#runner"] = "pytest"
vim.g["test#python#pytest#executable"] = "uv run --no-sync python -m pytest"
vim.g["test#strategy"] = "neovim"

local function context()
	local root = project.root()
	local python = project.python(root)
	if python then
		return { root = root, python = python }
	end
end

local function file(save)
	local path = vim.api.nvim_buf_get_name(0)
	if vim.bo.filetype ~= "python" or vim.bo.buftype ~= "" or path == "" then
		vim.notify("Open a named Python file first.", vim.log.levels.WARN)
		return
	end
	if save then
		vim.cmd.update()
	end
	return path
end

-- vim-test understands pytest functions and classes, including async tests.
-- Keep targets as argument lists so file paths are never parsed by a shell.
function M.test_target(kind)
	local ctx = context()
	if not ctx then
		return
	end
	if kind == "last" then
		if not last_tests[ctx.root] then
			vim.notify("No previous pytest run for this project.", vim.log.levels.INFO)
			return
		end
		if vim.bo.filetype == "python" and vim.bo.buftype == "" then
			vim.cmd.update()
		end
		return vim.deepcopy(last_tests[ctx.root])
	end
	ctx.args = {}
	if kind == "suite" then
		if vim.bo.filetype == "python" and vim.bo.buftype == "" then
			vim.cmd.update()
		end
	else
		local path = file(true)
		if not path then
			return
		end
		vim.fn["test#python#executable"]() -- Load vim-test's Python patterns.
		if vim.fn["test#python#pytest#test_file"](path) == 0 then
			vim.notify("Open a pytest test file for this action.", vim.log.levels.WARN)
			return
		end
		local cursor = vim.api.nvim_win_get_cursor(0)
		ctx.args = vim.fn["test#python#pytest#build_position"](kind, {
			file = path,
			line = cursor[1],
			col = cursor[2] + 1,
		})
	end
	return ctx
end

function M.test(kind)
	local ctx = M.test_target(kind)
	if ctx then
		local previous = test_terms[ctx.root]
		if previous and vim.fn.jobwait({ previous.job }, 0)[1] == -1 then
			vim.notify("Pytest is still running. Use i then Ctrl+c in its terminal to interrupt.", vim.log.levels.INFO)
			return
		end
		last_tests[ctx.root] = vim.deepcopy(ctx)
		local term = terminal.run(vim.list_extend({ ctx.python, "-m", "pytest" }, ctx.args), ctx.root, {
			insert = false,
			reuse = previous and previous.buf,
		})
		test_terms[ctx.root] = term
		return term
	end
end

function M.run_file()
	local ctx = context()
	local path = ctx and file(true)
	if path then
		return terminal.run({ ctx.python, path }, ctx.root)
	end
end

function M.repl(focus)
	local ctx = context()
	if not ctx then
		return
	end
	local source_win = vim.api.nvim_get_current_win()
	local repl = repls[ctx.root]
	if not (repl and vim.api.nvim_buf_is_valid(repl.buf) and vim.fn.jobwait({ repl.job }, 0)[1] == -1) then
		repl = terminal.run(
			{ ctx.python, vim.fn.stdpath("config") .. "/scripts/repl.py" },
			ctx.root,
			{ insert = false }
		)
		repls[ctx.root] = repl
	elseif vim.fn.bufwinid(repl.buf) == -1 then
		vim.cmd("botright 12split")
		vim.api.nvim_set_current_buf(repl.buf)
	else
		vim.api.nvim_set_current_win(vim.fn.bufwinid(repl.buf))
	end
	if focus then
		vim.cmd.startinsert()
	else
		vim.api.nvim_set_current_win(source_win)
	end
	return repl
end

function M.send(visual)
	local path = file(false)
	if not path then
		return
	end
	local lines
	if visual then
		lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	else
		lines = { vim.api.nvim_get_current_line() }
	end
	local repl = M.repl(false)
	if repl then
		-- A temporary file handles multiline code without terminal paste limits.
		local temp = vim.fn.tempname() .. ".py"
		vim.fn.writefile(lines, temp)
		vim.fn.chansend(repl.job, "_nvim_exec(" .. vim.json.encode(temp) .. ", " .. vim.json.encode(path) .. ")\n")
	end
end

for key, kind in pairs({ pn = "nearest", pf = "file", pa = "suite", pl = "last" }) do
	vim.keymap.set("n", "<leader>" .. key, function()
		M.test(kind)
	end, { desc = "Pytest: " .. kind })
end
vim.keymap.set("n", "<leader>pr", M.run_file, { desc = "Run Python file" })
vim.keymap.set("n", "<leader>pi", function()
	M.repl(true)
end, { desc = "Open project Python REPL" })
vim.keymap.set("n", "<leader>ps", function()
	M.send(false)
end, { desc = "Send line to Python REPL" })
vim.keymap.set("x", "<leader>ps", function()
	M.send(true)
end, { desc = "Send selection to Python REPL" })
vim.keymap.set("n", "<leader>ph", function()
	vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath("config") .. "/docs/python.md"))
end, { desc = "Open Python workflow guide" })

return M
