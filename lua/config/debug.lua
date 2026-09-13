local dap = require("dap")
local project = require("config.project")
local M = {}

dap.adapters.python = {
	type = "executable",
	command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
	args = { "-m", "debugpy.adapter" },
}
dap.defaults.python.terminal_win_cmd = "botright 12new"

local function configuration(name)
	return {
		type = "python",
		request = "launch",
		name = name,
		cwd = project.root,
		pythonPath = function()
			return project.python() or dap.ABORT
		end,
		console = "integratedTerminal",
		justMyCode = true,
	}
end

local current = configuration("Python: current file")
current.program = "${file}"
local with_args = vim.deepcopy(current)
with_args.name = "Python: current file with arguments"
with_args.args = function()
	return require("dap.utils").splitstr(vim.fn.input("Arguments: "))
end
local module = configuration("Python: module")
module.module = function()
	local name = vim.fn.input("Python module: ")
	return name ~= "" and name or dap.ABORT
end
module.args = with_args.args
dap.configurations.python = { current, with_args, module }

function M.test(kind)
	local ctx = require("config.python").test_target(kind)
	if ctx then
		local config = configuration("Pytest: " .. kind)
		config.cwd, config.pythonPath = ctx.root, ctx.python
		config.module, config.args = "pytest", ctx.args
		dap.run(config)
	end
end

vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticError" })
vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticWarn", linehl = "CursorLine" })
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
vim.keymap.set("n", "<leader>dB", function()
	vim.ui.input({ prompt = "Breakpoint condition: " }, function(value)
		if value and value ~= "" then
			dap.set_breakpoint(value)
		end
	end)
end, { desc = "Set conditional breakpoint" })
vim.keymap.set("n", "<leader>dc", function()
	if not dap.session() and vim.bo.filetype == "python" then
		vim.cmd.update()
	end
	dap.continue()
end, { desc = "Start / continue debugging" })
for key, action in pairs({ ["do"] = "step_over", di = "step_into", dO = "step_out", dq = "terminate" }) do
	vim.keymap.set("n", "<leader>" .. key, dap[action], { desc = "Debug: " .. action:gsub("_", " ") })
end
vim.keymap.set("n", "<leader>dn", function()
	M.test("nearest")
end, { desc = "Debug nearest pytest test" })
vim.keymap.set("n", "<leader>df", function()
	M.test("file")
end, { desc = "Debug pytest file" })
vim.keymap.set("n", "<leader>de", function()
	require("dap.ui.widgets").hover()
end, { desc = "Inspect value under cursor" })
local scopes
vim.keymap.set("n", "<leader>ds", function()
	local widgets = require("dap.ui.widgets")
	scopes = scopes or widgets.sidebar(widgets.scopes)
	scopes.toggle()
end, { desc = "Toggle debugger variables" })
vim.keymap.set("n", "<leader>dr", function()
	dap.repl.toggle()
end, { desc = "Toggle debugger console" })

return M
