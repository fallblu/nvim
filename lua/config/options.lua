-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.wrap = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.showtabline = 0
-- vim.opt.colorcolumn = "100"

vim.opt.mouse = ""
vim.opt.clipboard = "unnamedplus"

-- WSL clipboard fallback: only used if win32yank.exe isn't on PATH.
-- (Neovim's bundled binaries normally provide it.)
if vim.fn.has("wsl") == 1 and vim.fn.executable("win32yank.exe") == 0 then
  vim.g.clipboard = {
    name = "wsl-clip",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'powershell.exe -NoLogo -NoProfile -Command "Get-Clipboard"',
      ["*"] = 'powershell.exe -NoLogo -NoProfile -Command "Get-Clipboard"',
    },
    cache_enabled = 0,
  }
end
