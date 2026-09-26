-- Four-space blocks matching the shared clang-format style: case labels level
-- with their switch, access specifiers level with their class, and namespace
-- contents unindented. Header files use this filetype as well.
vim.bo.shiftwidth = 4
vim.bo.cinoptions = ":0,l1,g0,N-s"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "") .. "\n setlocal shiftwidth< cinoptions<"
