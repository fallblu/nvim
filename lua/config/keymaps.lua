-- Keymaps are automatically loaded on the VeryLazy event
-- Add any additional keymaps here

-- Disable Ex mode
vim.keymap.set("n", "Q", "<Nop>", { desc = "Disabled (was Ex mode)" })

-- Replace sequential buffer navigation with direct jumps.
vim.keymap.set("n", "<S-h>", "H", { desc = "Top of screen" })
vim.keymap.set("n", "<S-l>", "L", { desc = "Bottom of screen" })
vim.keymap.set("n", "[b", "<Nop>", { desc = "Use <leader>, to choose a buffer" })
vim.keymap.set("n", "]b", "<Nop>", { desc = "Use <leader>, to choose a buffer" })
