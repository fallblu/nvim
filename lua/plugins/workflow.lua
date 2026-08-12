return {
  -- Open buffers are destinations, not a sequence to cycle through.
  { "akinsho/bufferline.nvim", enabled = false },

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
}
