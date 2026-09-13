local conform = require("conform")
conform.setup({
	formatters_by_ft = { python = { "ruff_format" } },
	formatters = {
		ruff_format = {
			command = function(_, ctx)
				return require("config.project").executable("ruff", require("config.project").root(ctx.buf))
			end,
		},
	},
	format_on_save = function(buf)
		if vim.bo[buf].filetype == "python" and not vim.b[buf].disable_autoformat then
			return { timeout_ms = 2000, lsp_format = "never" }
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("vanilla_python_format", { clear = true }),
	pattern = "python",
	callback = function(event)
		vim.keymap.set("n", "<leader>cf", function()
			conform.format({ bufnr = event.buf, timeout_ms = 2000, lsp_format = "never" })
		end, { buffer = event.buf, desc = "Format Python (Ruff)" })
		vim.keymap.set("n", "<leader>cF", function()
			vim.b[event.buf].disable_autoformat = not vim.b[event.buf].disable_autoformat
			vim.notify("Format on save: " .. (vim.b[event.buf].disable_autoformat and "off" or "on"))
		end, { buffer = event.buf, desc = "Toggle format on save for this buffer" })
	end,
})
