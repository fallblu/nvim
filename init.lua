-- Set leaders before loading any plugin or mapping. <leader> means Space.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- :help 'number' | :help 'relativenumber' | :help 'undofile'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.undofile = true

-- Python's bundled filetype settings use four spaces; Lua uses two.
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = -1
vim.opt.autoindent = true
-- Also keep manually invoked native completion from inserting a selection.
vim.opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }
-- Four-space hanging indents; closing delimiters align with their opening line.
vim.g.python_indent = {
	open_paren = "shiftwidth()",
	nested_paren = "shiftwidth()",
	continue = "shiftwidth()",
	closed_paren_align_last_line = false,
}

-- Appearance and predictable split placement.
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.winborder = "rounded"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 5

-- Lowercase searches ignore case; a capital letter makes them case-sensitive.
vim.opt.ignorecase = true
vim.opt.smartcase = true

require("config.plugins")
require("config.terminal")
require("config.keymaps")

vim.keymap.set("n", "<leader>?", function()
	vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath("config") .. "/README.md"))
end, { desc = "Open this configuration's guide" })
