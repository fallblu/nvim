-- Pyright installed by uv takes precedence over Mason's standalone fallback.
-- Each project gets its own client, command, interpreter, and pyproject settings.
vim.lsp.config("pyright", {
	settings = { pyright = { disableOrganizeImports = true } },
	cmd = function(dispatchers, config)
		local root = config.root_dir or vim.fn.getcwd()
		local executable = vim.fs.joinpath(root, ".venv", "bin", "pyright-langserver")
		if vim.fn.executable(executable) ~= 1 then
			executable = "pyright-langserver"
		end
		return vim.lsp.rpc.start({ executable, "--stdio" }, dispatchers, { cwd = root })
	end,
	before_init = function(_, config)
		local python = vim.fs.joinpath(config.root_dir or vim.fn.getcwd(), ".venv", "bin", "python")
		if vim.fn.executable(python) == 1 then
			config.settings.python.pythonPath = python
		end
	end,
})

vim.lsp.config("ruff", {
	cmd = function(dispatchers, config)
		local root = config.root_dir or vim.fn.getcwd()
		local executable = require("config.project").executable("ruff", root)
		return vim.lsp.rpc.start({ executable, "server" }, dispatchers, { cwd = root })
	end,
	on_attach = function(client)
		-- Pyright supplies documentation; Ruff supplies lint diagnostics and fixes.
		client.server_capabilities.hoverProvider = false
	end,
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
	virtual_text = { current_line = true, severity = { min = vim.diagnostic.severity.WARN } },
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("vanilla_lsp", { clear = true }),
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if not client then
			return
		end
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = event.buf, desc = "Go to definition" })
		vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { buffer = event.buf, desc = "Show diagnostic" })
		if client.name == "ruff" then
			for key, action in pairs({ ci = "source.organizeImports", cx = "source.fixAll" }) do
				vim.keymap.set("n", "<leader>" .. key, function()
					vim.lsp.buf.code_action({
						context = { only = { action }, diagnostics = {} },
						filter = function(item)
							return item.kind == action .. ".ruff"
						end,
						apply = true,
					})
				end, {
					buffer = event.buf,
					desc = key == "ci" and "Organize imports (Ruff)" or "Apply lint fixes (Ruff)",
				})
			end
		end
		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
			vim.keymap.set(
				"i",
				"<C-Space>",
				vim.lsp.completion.get,
				{ buffer = event.buf, desc = "Request completion" }
			)
		end
		-- Neovim supplies K, grr, grn, gra, gri, grt, gO, [d, and ]d.
	end,
})

vim.lsp.enable({ "pyright", "ruff", "lua_ls" })
