-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Disable Ex mode
vim.keymap.set("n", "Q", "<Nop>", { desc = "Disabled (was Ex mode)" })

-- Replace LazyVim's sequential buffer navigation with direct jumps.
vim.keymap.set("n", "<S-h>", "H", { desc = "Top of screen" })
vim.keymap.set("n", "<S-l>", "L", { desc = "Bottom of screen" })
vim.keymap.set("n", "[b", "<Nop>", { desc = "Use <leader>, to choose a buffer" })
vim.keymap.set("n", "]b", "<Nop>", { desc = "Use <leader>, to choose a buffer" })
