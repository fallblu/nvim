local project = require("config.project")
local terminal = require("config.terminal")
local M = {}
local programs, runs = {}, {} -- Chosen programs and run terminals, by project root.

-- Compiler warnings match clangd's inline diagnostics. The sanitizers report
-- memory errors and undefined behavior while the program runs; Valgrind builds
-- leave them out because the two cannot run together.
M.flags = { "-std=c17", "-Wall", "-Wextra", "-Wpedantic", "-g", "-O0" }
M.sanitizers = { "-fsanitize=address,undefined" }

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

-- The nearest directory with a Makefile or compile database, else the project
-- root, else the file's own directory.
function M.root(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local source = vim.b[buf].terminal_project_root or buf
	local root = vim.fs.root(source, { "GNUmakefile", "makefile", "Makefile", "compile_commands.json" })
		or vim.fs.root(source, { ".git", "pyproject.toml" })
	if root then
		return root
	end
	local name = vim.api.nvim_buf_get_name(buf)
	if name ~= "" and vim.bo[buf].buftype == "" then
		return vim.fs.dirname(name)
	end
	return project.root(buf)
end

local function makefile(root)
	for _, name in ipairs({ "GNUmakefile", "makefile", "Makefile" }) do
		if vim.fn.filereadable(vim.fs.joinpath(root, name)) == 1 then
			return true
		end
	end
	return false
end

-- Bear records each compile command in compile_commands.json, so clangd checks
-- a make-built project with its real flags.
local function make(args)
	local command = vim.fn.executable("bear") == 1 and { "bear", "--append", "--", "make" } or { "make" }
	return vim.list_extend(command, args or {})
end

-- clangd reads compile_commands.json when it starts, so restart this
-- project's clients after make changed the recorded commands.
local function restart_clangd(root)
	for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
		if client.root_dir == root then
			local buffers = vim.lsp.get_buffers_by_client_id(client.id)
			local config = client.config
			client:stop()
			local timer = assert(vim.uv.new_timer())
			timer:start(100, 100, function()
				if not client:is_stopped() then
					return
				end
				timer:stop()
				timer:close()
				vim.schedule(function()
					for _, buf in ipairs(buffers) do
						if vim.api.nvim_buf_is_valid(buf) then
							vim.lsp.start(config, { bufnr = buf })
						end
					end
				end)
			end)
		end
	end
end

local function database(root)
	local path = vim.fs.joinpath(root, "compile_commands.json")
	return vim.fn.filereadable(path) == 1 and table.concat(vim.fn.readfile(path), "\n") or ""
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
local function build(command, root, label, quiet)
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
	if not quiet then
		vim.notify(label .. (count > 0 and " finished with warnings" or " finished"))
	end
	return true
end

-- Run make through Bear, refreshing clangd when the compile database changed.
local function run_make(args, root, label)
	local before = database(root)
	local ok = build(make(args), root, label)
	if database(root) ~= before then
		restart_clangd(root)
	end
	return ok
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
		if run_make(nil, root, "make") then
			return root, path
		end
		return
	end
	local program = vim.fn.fnamemodify(path, ":r")
	local command = vim.list_extend({ "gcc" }, M.flags)
	vim.list_extend(command, M.sanitizers)
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

-- The remembered program, else the one named after the source, else a choice.
local function locate(root, path)
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

-- Build, then locate the program for the current file.
function M.program()
	local root, path, program = M.build()
	if not root then
		return
	end
	return program or locate(root, path)
end

-- Run a command in a project terminal below. A repeat run reuses the visible
-- window and stops a program that is still running there.
local function run(command, root)
	local previous = runs[root]
	if previous and vim.fn.jobwait({ previous.job }, 0)[1] == -1 then
		vim.fn.jobstop(previous.job)
	end
	runs[root] = terminal.run(command, root, { reuse = previous and previous.buf })
end

local function arguments()
	return require("dap.utils").splitstr(vim.fn.input("Arguments: "))
end

-- Build, then run the program.
function M.run(with_arguments)
	local program = M.program()
	if not program then
		return
	end
	local command = { program }
	if with_arguments then
		vim.list_extend(command, arguments())
	end
	run(command, M.root())
end

-- Build a copy without sanitizers beside the program, then run it under
-- Valgrind's memory checker. A Makefile is asked to honor SANITIZE=0, and its
-- sanitized build is restored afterwards.
function M.valgrind(with_arguments)
	if vim.fn.executable("valgrind") ~= 1 then
		vim.notify("Valgrind is not installed: sudo apt install valgrind", vim.log.levels.WARN)
		return
	end
	local path = source(true)
	if not path then
		return
	end
	local root = M.root()
	local copy
	if makefile(root) then
		if not build({ "make", "-B", "SANITIZE=0" }, root, "make -B SANITIZE=0") then
			return
		end
		local program = locate(root, path)
		if not program then
			return
		end
		copy = program .. ".valgrind"
		local copied, err = vim.uv.fs_copyfile(program, copy)
		if not copied then
			vim.notify("Could not copy " .. program .. ": " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		vim.uv.fs_chmod(copy, tonumber("755", 8))
		build({ "make", "-B" }, root, "make -B", true)
	else
		copy = vim.fn.fnamemodify(path, ":r") .. ".valgrind"
		local command = vim.list_extend({ "gcc" }, M.flags)
		vim.list_extend(command, { "-o", copy, path })
		if not build(command, root, "gcc " .. vim.fn.fnamemodify(path, ":t") .. " without sanitizers") then
			return
		end
	end
	if vim.fn.executable("readelf") == 1 then
		local dynamic = vim.system({ "readelf", "--dynamic", copy }, { text = true }):wait().stdout or ""
		if dynamic:find("libasan", 1, true) then
			vim.notify(
				"The program links AddressSanitizer, which Valgrind cannot run alongside. "
					.. "Let the Makefile skip -fsanitize when SANITIZE=0.",
				vim.log.levels.ERROR
			)
			return
		end
	end
	local command = { "valgrind", "--leak-check=full", "--track-origins=yes", "-s", "--error-exitcode=1", copy }
	if with_arguments then
		vim.list_extend(command, arguments())
	end
	run(command, root)
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
	run_make(require("dap.utils").splitstr(target), root, "make " .. target)
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
vim.keymap.set("n", "<leader>mv", function()
	M.valgrind(false)
end, { desc = "Build without sanitizers and run under Valgrind" })
vim.keymap.set("n", "<leader>mV", function()
	M.valgrind(true)
end, { desc = "Build without sanitizers and run under Valgrind with arguments" })
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
