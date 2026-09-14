local map = vim.keymap.set

for key, direction in pairs({ h = "left", j = "below", k = "above", l = "right" }) do
	map("n", "<C-" .. key .. ">", "<C-w>" .. key, { desc = "Focus window " .. direction })
end
map("n", "<leader>|", "<C-w>v", { desc = "Split window right" })
map("n", "<leader>-", "<C-w>s", { desc = "Split window below" })
for key, spec in pairs({
	v = { "v", "Split right" },
	s = { "s", "Split below" },
	d = { "c", "Close window" },
	o = { "o", "Keep only this window" },
	w = { "w", "Next window" },
	["="] = { "=", "Equalize windows" },
	H = { "H", "Move window to left edge" },
	J = { "J", "Move window to bottom edge" },
	K = { "K", "Move window to top edge" },
	L = { "L", "Move window to right edge" },
}) do
	map("n", "<leader>w" .. key, "<C-w>" .. spec[1], { desc = spec[2] })
end
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

map("x", "<", "<gv", { desc = "Unindent and keep selection" })
map("x", ">", ">gv", { desc = "Indent and keep selection" })
map("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", { desc = "Clear search highlighting" })
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })
