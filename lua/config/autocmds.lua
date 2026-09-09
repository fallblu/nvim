-- Autocmds are automatically loaded on the VeryLazy event
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
local augroup = vim.api.nvim_create_augroup("garrett_python", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = "python",
  callback = function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt_local.foldlevel = 99
    vim.opt_local.foldlevelstart = 99
  end,
})

local spell_group = vim.api.nvim_create_augroup("garrett_code_spell", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = spell_group,
  pattern = vim.list_extend({ "python" }, require("config.filetypes").agda),
  callback = function()
    -- Tree-sitter/syntax @spell captures restrict checking to comments and
    -- documentation rather than identifiers in ordinary source code.
    vim.opt_local.spell = true
  end,
})
