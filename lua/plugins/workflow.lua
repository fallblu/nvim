return {
  -- Open buffers are destinations, not a sequence to cycle through.
  { "akinsho/bufferline.nvim", enabled = false },

  -- LazyVim selects an explorer by default, so explicitly neutralize its
  -- Snacks fallback while retaining Snacks for pickers and terminals.
  {
    "folke/snacks.nvim",
    opts = { explorer = { enabled = false } },
    keys = {
      { "<leader>fe", false },
      { "<leader>fE", false },
      { "<leader>e", false },
      { "<leader>E", false },
    },
  },

  -- Tests run through neotest or an embedded terminal; no debug adapter UI.
  { "mfussenegger/nvim-dap", enabled = false },
  { "mfussenegger/nvim-dap-python", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },

  {
    "m4xshen/hardtime.nvim",
    lazy = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    keys = {
      { "<leader>uH", "<cmd>Hardtime toggle<cr>", desc = "Toggle Hardtime" },
    },
    opts = {
      max_time = 1000,
      max_count = 3,
      restriction_mode = "block",
      force_exit_insert_mode = true,
      max_insert_idle_ms = 10000,
      restricted_keys = {
        ["w"] = { "n", "x" },
      },
      disabled_keys = {
        ["v"] = { "n" },
        ["V"] = { "n" },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        update_in_insert = false,
        severity_sort = true,
        virtual_lines = false,
        virtual_text = {
          current_line = true,
          severity = { min = vim.diagnostic.severity.WARN },
          spacing = 2,
          source = "if_many",
          prefix = "●",
        },
        underline = {
          severity = { min = vim.diagnostic.severity.WARN },
        },
      },
    },
  },

  -- Accept completion explicitly with <C-y>; <Enter> always inserts a newline.
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<CR>"] = { "fallback" },
      },
    },
  },
}
