local project = require("config.project")
local terminal = require("config.terminal")
local M = {}
local programs, runs = {}, {} -- Chosen programs and run terminals, by project root.

-- Compiler warnings match clangd's inline diagnostics; the sanitizers report
-- memory errors and undefined behavior while the program runs.
M.flags = { "-std=c17", "-Wall", "-Wextra", "-Wpedantic", "-g", "-O0", "-fsanitize=address,undefined" }

-- gcc and linker diagnostics plus make's directory changes; other lines are dropped.
local errorformat = table.concat({
	"%f:%l:%c: fatal %trror: %m",
	"%f:%l:%c: %trror: %m",
	"%f:%l:%c: %tarning: %m",
	"%f:%l:%c: %tote: %m",
	"%f:%l:%c: %m",
	"%f:%l:(%*[^)]): %m",
	"%f:(%*[^)]): %m",
	"%*[^:]: %f:%l:(%*[^)]): %m",
	"%*[^:]: %f:(%*[^)]): %m",
	"%D%*\\a[%*\\d]: Entering directory %*[`']%f'",
	"%X%*\\a[%*\\d]: Leaving directory %*[`']%f'",
	"%D%*\\a: Entering directory %*[`']%f'",
	"%X%*\\a: Leaving directory %*[`']%f'",
	"%-G%.%#",
}, ",")

-- The nearest directory with a Makefile or compile database, else the project root.
function M.root(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local source = vim.b[buf].terminal_project_root or buf
	return vim.fs.root(source, { "GNUmakefile", "makefile", "Makefile", "compile_commands.json" }) or project.root(buf)
end

local function makefile(root)
	for _, name in ipairs({ "GNUmakefile", "makefile", "Makefile" }) do
		if vim.fn.filereadable(vim.fs.joinpath(root, name)) == 1 then
			return true
		end
	end
	return false
end

local function source(save)
	local path = vim.api.nvim_buf_get_name(0)
	if vim.bo.filetype ~= "c" or vim.bo.buftype ~= "" or path == "" then
		vim.notify("Open a named C file first.", vim.log.levels.WARN)
		return
	end
	if save then
		vim.cmd.update()
	end
	return path
end

-- Run a build command to completion; its diagnostics fill the quickfix list.
local function build(command, root, label)
	local ok, result = pcall(function()
		return vim.system(command, { cwd = root, text = true }):wait()
	end)
	if not ok then
		vim.notify("Could not run " .. command[1] .. ": " .. tostring(result), vim.log.levels.ERROR)
		return false
	end
	local output = vim.split((result.stdout or "") .. (result.stderr or ""), "\n", { trimempty = true })
	vim.fn.setqflist({}, " ", { title = label, lines = output, efm = errorformat })
	local count = #vim.fn.getqflist()
	if count > 0 then
		vim.cmd.copen()
		vim.cmd.wincmd("p")
	else
		vim.cmd.cclose()
	end
	if result.code ~= 0 then
		local detail = count > 0 and (count .. " diagnostics; ]q and [q visit them")
			or table.concat(vim.list_slice(output, math.max(1, #output - 11)), "\n")
		vim.notify(label .. " failed: " .. detail, vim.log.levels.ERROR)
		return false
	end
	vim.notify(label .. (count > 0 and " finished with warnings" or " finished"))
	return true
end

-- Save, then run make in the nearest Makefile directory or compile this file
-- alone into a program beside it. Returns the root, the source, and the program
-- when the build itself determines it.
function M.build()
	local path = source(true)
	if not path then
		return
	end
	local root = M.root()
	if makefile(root) then
		if build({ "make" }, root, "make") then
			return root, path
		end
		return
	end
	local program = vim.fn.fnamemodify(path, ":r")
	local command = vim.list_extend({ "gcc" }, M.flags)
	vim.list_extend(command, { "-o", program, path })
	if build(command, root, "gcc " .. vim.fn.fnamemodify(path, ":t")) then
		return root, path, program
	end
end

-- Remember which program to run or debug when make builds something other
-- than a program named after the current file.
function M.choose_program(root)
	root = root or M.root()
	local chosen = vim.fn.input({ prompt = "Program to run: ", default = root .. "/", completion = "file" })
	if chosen == "" then
		return
	end
	chosen = vim.fs.normalize(chosen)
	if not chosen:match("^/") then
		chosen = vim.fs.joinpath(root, chosen)
	end
	if vim.fn.executable(chosen) ~= 1 then
		vim.notify(chosen .. " is not an executable program.", vim.log.levels.WARN)
		return
	end
	programs[root] = chosen
	return chosen
end

-- Build, then locate the program for the current file.
function M.program()
	local root, path, program = M.build()
	if not root then
		return
	end
	if program then
		return program
	end
	local remembered = programs[root]
	if remembered and vim.fn.executable(remembered) == 1 then
		return remembered
	end
	local beside = vim.fn.fnamemodify(path, ":r")
	if vim.fn.executable(beside) == 1 then
		return beside
	end
	return M.choose_program(root)
end

-- Build, then run the program in a project terminal below. A repeat run reuses
-- the visible window and stops a program that is still running there.
function M.run(with_arguments)
	local program = M.program()
	if not program then
		return
	end
	local command = { program }
	if with_arguments then
		vim.list_extend(command, require("dap.utils").splitstr(vim.fn.input("Arguments: ")))
	end
	local root = M.root()
	local previous = runs[root]
	if previous and vim.fn.jobwait({ previous.job }, 0)[1] == -1 then
		vim.fn.jobstop(previous.job)
	end
	runs[root] = terminal.run(command, root, { reuse = previous and previous.buf })
end

-- Run any target of the nearest Makefile, such as clean or test.
function M.make(target)
	local root = M.root()
	if not makefile(root) then
		vim.notify("No Makefile found for " .. root, vim.log.levels.WARN)
		return
	end
	target = target or vim.fn.input("make target: ")
	if target == "" then
		return
	end
	if vim.bo.filetype == "c" and vim.bo.buftype == "" then
		vim.cmd.update()
	end
	build(vim.list_extend({ "make" }, require("dap.utils").splitstr(target)), root, "make " .. target)
end

-- Library documentation: section 3 (functions), then 2 (system calls), then any.
function M.man()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end
	for _, args in ipairs({ { "3", word }, { "2", word }, { word } }) do
		if vim.system(vim.list_extend({ "man", "--where" }, args)):wait().code == 0 then
			vim.cmd.Man({ args = args })
			return
		end
	end
	vim.notify("No manual page for " .. word, vim.log.levels.WARN)
end

vim.keymap.set("n", "<leader>mb", M.build, { desc = "Build: make, or gcc for this file" })
vim.keymap.set("n", "<leader>mr", function()
	M.run(false)
end, { desc = "Build and run the program" })
vim.keymap.set("n", "<leader>mR", function()
	M.run(true)
end, { desc = "Build and run the program with arguments" })
vim.keymap.set("n", "<leader>mp", function()
	M.choose_program()
end, { desc = "Choose the program to run or debug" })
vim.keymap.set("n", "<leader>mm", function()
	M.make()
end, { desc = "Run a make target" })
vim.keymap.set("n", "<leader>mq", function()
	if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
		vim.cmd.cclose()
	else
		vim.cmd.copen()
	end
end, { desc = "Toggle the build diagnostics list" })
vim.keymap.set("n", "<leader>mk", M.man, { desc = "Manual page for the word under the cursor" })
vim.keymap.set("n", "<leader>mh", function()
	vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath("config") .. "/docs/c.md"))
end, { desc = "Open C workflow guide" })

return M
