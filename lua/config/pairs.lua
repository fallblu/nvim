local pairs = require("nvim-autopairs")
pairs.setup({
	map_cr = false,
	disable_filetype = { "TelescopePrompt", "snacks_picker_input" },
	-- The bundled filetype indent scripts handle multiline pairs, including Python.
	check_ts = false,
})

vim.keymap.set("i", "<CR>", function()
	-- Native completion must also be dismissed, never confirmed by Enter.
	if vim.fn.pumvisible() == 1 then
		return vim.keycode("<C-e><CR>")
	end
	return pairs.autopairs_cr()
end, { expr = true, replace_keycodes = false, desc = "Newline with paired indentation" })

vim.keymap.set("n", "<leader>up", function()
	pairs.toggle()
	vim.notify("Automatic pairs: " .. (pairs.state.disabled and "off" or "on"))
end, { desc = "Toggle automatic pairs" })
