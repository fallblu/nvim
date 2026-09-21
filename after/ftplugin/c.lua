-- Four-space blocks with case labels level with their switch, matching the
-- shared clang-format style. Header files use this filetype as well.
vim.bo.shiftwidth = 4
vim.bo.cinoptions = ":0,l1"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "") .. "\n setlocal shiftwidth< cinoptions<"
