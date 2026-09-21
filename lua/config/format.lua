local conform = require("conform")
local project = require("config.project")
local formatted = { python = true, c = true }
local style = vim.fn.stdpath("config") .. "/styles/clang-format.yaml"

conform.setup({
	formatters_by_ft = { python = { "ruff_format" }, c = { "clang_format" } },
	formatters = {
		ruff_format = {
			command = function(_, ctx)
				return project.executable("ruff", project.root(ctx.buf))
			end,
		},
		clang_format = {
			-- A project's own .clang-format wins; otherwise use the shared style.
			args = function(_, ctx)
				local own = vim.fs.find({ ".clang-format", "_clang-format" }, { path = ctx.dirname, upward = true })
				return { "-assume-filename", "$FILENAME", "--style=" .. (#own > 0 and "file" or "file:" .. style) }
			end,
		},
	},
	format_on_save = function(buf)
		if formatted[vim.bo[buf].filetype] and not vim.b[buf].disable_autoformat then
			return { timeout_ms = 2000, lsp_format = "never" }
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("vanilla_format", { clear = true }),
	pattern = vim.tbl_keys(formatted),
	callback = function(event)
		vim.keymap.set("n", "<leader>cf", function()
			conform.format({ bufnr = event.buf, timeout_ms = 2000, lsp_format = "never" })
		end, { buffer = event.buf, desc = "Format (Ruff or clang-format)" })
		vim.keymap.set("n", "<leader>cF", function()
			vim.b[event.buf].disable_autoformat = not vim.b[event.buf].disable_autoformat
			vim.notify("Format on save: " .. (vim.b[event.buf].disable_autoformat and "off" or "on"))
		end, { buffer = event.buf, desc = "Toggle format on save for this buffer" })
	end,
})
