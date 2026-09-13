-- Language-server support is limited to Lua.
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

vim.lsp.enable("lua_ls")
