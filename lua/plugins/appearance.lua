local colorscheme = require("config.colorscheme")

local header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
]]

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = colorscheme.load,
      news = { lazyvim = false },
    },
  },

  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>uC", colorscheme.pick, desc = "Choose Colorscheme" },
    },
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}
      opts.dashboard.preset.header = header
      opts.dashboard.preset.keys = {
        { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
        { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
        { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
        {
          icon = " ",
          key = "c",
          desc = "Config",
          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
        },
        { icon = "󰫈 ", key = "s", desc = "Restore Session", section = "session" },
        { icon = "󱝕 ", key = "t", desc = "Colorschemes", action = colorscheme.pick },
        { icon = "󰳲 ", key = "u", desc = "Plugin Updates", action = ":Lazy" },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      }
      opts.dashboard.sections = {
        { section = "header" },
        function()
          return {
            text = "󰃋  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
            align = "center",
            padding = 1,
          }
        end,
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }
    end,
  },

  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      background = { dark = "wave", light = "lotus" },
      theme = "wave",
    },
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      dark_variant = "main",
    },
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    opts = {
      contrast = "hard",
    },
  },
  {
    "EdenEast/nightfox.nvim",
    lazy = true,
  },
  {
    "sainnhe/everforest",
    lazy = true,
    init = function()
      vim.g.everforest_background = "hard"
      vim.g.everforest_better_performance = 1
    end,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = true,
  },
}
