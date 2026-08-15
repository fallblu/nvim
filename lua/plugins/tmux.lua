local tmux = require("config.tmux")

return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window or tmux pane" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window or tmux pane" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window or tmux pane" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window or tmux pane" },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      terminal = {
        win = {
          keys = {
            nav_h = { "<C-h>", tmux.snacks_key("h"), desc = "Go to left window or tmux pane", expr = true },
            nav_j = { "<C-j>", tmux.snacks_key("j"), desc = "Go to lower window or tmux pane", expr = true },
            nav_k = { "<C-k>", tmux.snacks_key("k"), desc = "Go to upper window or tmux pane", expr = true },
            nav_l = { "<C-l>", tmux.snacks_key("l"), desc = "Go to right window or tmux pane", expr = true },
          },
        },
      },
    },
  },
}
