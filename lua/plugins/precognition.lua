return {
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>uP",
        function()
          local visible = require("precognition").toggle()
          vim.notify("Precognition " .. (visible and "enabled" or "disabled"), nil, { title = "Precognition" })
        end,
        desc = "Toggle Precognition",
      },
    },
    opts = {
      startVisible = false,
      showBlankVirtLine = false,
      highlightColor = { link = "Comment" },
      disabled_fts = {
        "checkhealth",
        "lazy",
        "mason",
        "startify",
        "snacks_dashboard",
        "snacks_picker_input",
        "snacks_picker_list",
        "snacks_picker_preview",
      },
    },
  },
}
