local project = require("config.project")

vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

-- Share project boundaries with the picker, formatter, tests, and REPL.
local function python_root(buf, on_dir)
	-- Ruff requires a file URI; wait until scratch buffers have a filename.
	if vim.api.nvim_buf_get_name(buf) ~= "" and vim.bo[buf].buftype == "" then
		on_dir(project.root(buf))
	end
end

vim.lsp.config("basedpyright", {
	root_dir = python_root,
	before_init = function(_, config)
		local python = vim.fs.joinpath(config.root_dir, ".venv", "bin", "python")
		if vim.fn.executable(python) == 1 then
			config.settings.python = vim.tbl_extend("force", config.settings.python or {}, { pythonPath = python })
		end
	end,
	settings = {
		basedpyright = {
			disableOrganizeImports = true, -- Ruff owns import actions.
			analysis = {
				autoImportCompletions = true,
				autoSearchPaths = true,
				diagnosticMode = "openFilesOnly",
				typeCheckingMode = "basic", -- Project configuration can opt into stricter checks.
			},
		},
	},
})

vim.lsp.config("ruff", {
	root_dir = python_root,
	capabilities = {
		textDocument = {
			formatting = { dynamicRegistration = false },
			rangeFormatting = { dynamicRegistration = false },
		},
	},
	cmd = function(dispatchers, config)
		return vim.lsp.rpc.start({ project.executable("ruff", config.root_dir), "server" }, dispatchers, {
			cwd = config.root_dir,
		})
	end,
	on_init = function(client)
		client.server_capabilities.hoverProvider = false
		-- Conform owns formatting; lint fixes and import actions remain explicit.
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end,
})

-- clangd also waits for a filename; without a compile database it uses these flags.
vim.lsp.config("clangd", {
	cmd = { "clangd", "--background-index", "--clang-tidy", "--completion-style=detailed" },
	root_dir = function(buf, on_dir)
		local path = vim.api.nvim_buf_get_name(buf)
		if path ~= "" and vim.bo[buf].buftype == "" then
			on_dir(require("config.c").root(buf))
		end
	end,
	init_options = { fallbackFlags = { "-std=c17", "-Wall", "-Wextra", "-Wpedantic" } },
	-- Plain names for function completions, as with Python: type ( to start a call.
	capabilities = { textDocument = { completion = { completionItem = { snippetSupport = false } } } },
})

vim.lsp.config("lua_ls", {
	on_init = function(client)
		-- Neovim API knowledge belongs to this configuration, not every Lua project.
		if client.config.root_dir == vim.fn.stdpath("config") then
			client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
				runtime = { version = "LuaJIT" },
				workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
			})
		end
	end,
})

vim.diagnostic.config({
	severity_sort = true,
	update_in_insert = false,
	virtual_text = false,
	virtual_lines = false,
	float = { border = "rounded", source = "if_many" },
})

vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Show diagnostic" })
vim.keymap.set("n", "<leader>cD", vim.diagnostic.setqflist, { desc = "List workspace diagnostics" })
vim.keymap.set("n", "<leader>ud", function()
	local buf = vim.api.nvim_get_current_buf()
	local enabled = not vim.diagnostic.is_enabled({ bufnr = buf })
	vim.diagnostic.enable(enabled, { bufnr = buf })
	vim.notify("Diagnostics: " .. (enabled and "on" or "off"))
end, { desc = "Toggle diagnostics for this buffer" })

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("vanilla_lsp", { clear = true }),
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if not client then
			return
		end
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = event.buf, desc = "Go to definition" })
		if client:supports_method("textDocument/hover") then
			-- Python's ftplugin sets keywordprg, which suppresses Neovim's default K mapping.
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = event.buf, desc = "Hover documentation" })
		end
		vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = event.buf, desc = "Rename symbol" })
		vim.keymap.set(
			{ "n", "x" },
			"<leader>ca",
			vim.lsp.buf.code_action,
			{ buffer = event.buf, desc = "Code action" }
		)
		if client:supports_method("textDocument/signatureHelp") then
			vim.keymap.set("i", "<C-g>s", vim.lsp.buf.signature_help, { buffer = event.buf, desc = "Signature help" })
		end
		if client:supports_method("textDocument/inlayHint") then
			vim.keymap.set("n", "<leader>uh", function()
				vim.lsp.inlay_hint.enable(
					not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
					{ bufnr = event.buf }
				)
			end, { buffer = event.buf, desc = "Toggle inlay hints for this buffer" })
		end
		if client.name == "clangd" then
			vim.keymap.set("n", "<leader>ch", function()
				vim.cmd.LspClangdSwitchSourceHeader()
			end, { buffer = event.buf, desc = "Switch between C source and header" })
		end
		if client.name == "ruff" then
			vim.keymap.set("n", "<leader>co", function()
				vim.lsp.buf.code_action({
					context = { only = { "source.organizeImports" }, diagnostics = {} },
					filter = function(action)
						return action.kind and action.kind:match("^source%.organizeImports") ~= nil
					end,
					apply = true,
				})
			end, { buffer = event.buf, desc = "Organize imports (Ruff)" })
		end
		-- Neovim supplies K, grr, grn, gra, gri, grt, gO, [d, and ]d.
	end,
})

vim.lsp.enable({ "lua_ls", "basedpyright", "ruff", "clangd" })

vim.api.nvim_create_autocmd("BufWritePost", {
	group = vim.api.nvim_create_augroup("vanilla_first_save", { clear = true }),
	callback = function(event)
		local filetype = vim.bo[event.buf].filetype
		if (filetype == "python" or filetype == "c") and #vim.lsp.get_clients({ bufnr = event.buf }) == 0 then
			-- :setfiletype on an unnamed buffer precedes its first usable file URI.
			vim.api.nvim_exec_autocmds("FileType", { group = "nvim.lsp.enable", buffer = event.buf, modeline = false })
		end
	end,
})
