-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Escape via jk / kj in insert, visual, command-line, operator-pending, and terminal.
local esc_modes = { "i", "v", "c", "o" }
for _, lhs in ipairs({ "jk", "kj" }) do
  vim.keymap.set(esc_modes, lhs, "<Esc>", { desc = "Exit to normal mode" })
  vim.keymap.set("t", lhs, [[<C-\><C-n>]], { desc = "Exit terminal mode" })
end

-- Keep visual selection after indent
vim.keymap.set("v", "<", "<gv", { desc = "Indent left, keep selection" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right, keep selection" })

-- Disable Ex mode
vim.keymap.set("n", "Q", "<Nop>", { desc = "Disabled (was Ex mode)" })

-- Force hjkl: disable arrows in normal & visual (insert-mode arrows left intact)
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  vim.keymap.set({ "n", "v" }, key, "<Nop>", { desc = "Use hjkl" })
end
