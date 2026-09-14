vim.keymap.set("n", "<leader>uc", function()
	vim.b.completion_manual = not vim.b.completion_manual
	require("blink.cmp").hide()
	vim.notify("Automatic completion menu: " .. (vim.b.completion_manual and "off" or "on"))
end, { desc = "Toggle automatic completion for this buffer" })

return {
	keymap = {
		preset = "none",
		["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
		-- Selection and acceptance are separate, intentional actions.
		["<C-n>"] = { "select_next", "show" },
		["<C-p>"] = { "select_prev", "show" },
		["<CR>"] = { "accept", "fallback" },
		["<C-e>"] = { "cancel", "fallback" },
		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		["<C-f>"] = { "scroll_documentation_down", "fallback" },
		["<Tab>"] = { "snippet_forward", "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },
		-- Enter falls back to paired newline handling when no item is selected.
		-- Arrow keys retain their editing behavior.
	},
	completion = {
		list = { selection = { preselect = false, auto_insert = false } },
		trigger = {
			show_on_insert = false,
			show_on_insert_on_trigger_character = false,
			show_on_accept_on_trigger_character = false,
		},
		-- Type parentheses yourself; accepting a function may also mean passing it as a value.
		accept = { auto_brackets = { enabled = false } },
		menu = {
			auto_show = function()
				return not vim.b.completion_manual
			end,
			auto_show_delay_ms = 150,
			max_height = 8,
			border = "rounded",
			draw = { columns = { { "label", "label_description", gap = 1 }, { "kind" }, { "source_name" } } },
		},
		documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = "rounded" } },
		ghost_text = { enabled = true, show_without_selection = false, show_without_menu = false },
	},
	-- Prefer server knowledge; buffer words are a fallback when the LSP has no matches.
	sources = { default = { "lsp", "path", "snippets", "buffer" } },
	fuzzy = { implementation = "lua" }, -- No native build or binary download required.
	signature = { enabled = false }, -- Request signatures explicitly with Ctrl+s.
	cmdline = { enabled = false },
	term = { enabled = false },
}
