-- Terminal keymaps backed by snacks.nvim (already loaded by LazyVim).
--
-- Layout:
--   <C-/>          toggle float terminal (works in both normal and terminal mode)
--   <leader>;<x>   terminal-group prefix (chosen to avoid colliding with
--                  <leader>t* which the test extra owns)
--
-- snacks terminals are persistent per-key — toggling closes/reopens the same
-- shell, so you can leave a long-running process and pop back to it.

local function snacks_term(cmd, opts)
  return function()
    require("snacks").terminal(cmd, opts)
  end
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<C-/>", snacks_term(), mode = { "n", "t" }, desc = "Toggle terminal" },
      { "<C-_>", snacks_term(), mode = { "n", "t" }, desc = "Toggle terminal (alt)" },

      { "<leader>;", "", desc = "+terminal" },
      { "<leader>;t", snacks_term(), desc = "Terminal (float)" },
      {
        "<leader>;s",
        snacks_term(nil, { win = { position = "bottom", height = 0.4 } }),
        desc = "Terminal (hsplit)",
      },
      {
        "<leader>;v",
        snacks_term(nil, { win = { position = "right", width = 0.4 } }),
        desc = "Terminal (vsplit)",
      },
      {
        "<leader>;g",
        function()
          require("snacks").lazygit()
        end,
        desc = "Lazygit",
      },
      {
        "<leader>;p",
        function()
          local cmd = vim.fn.executable("ipython") == 1 and "ipython" or "python"
          require("snacks").terminal(cmd, { win = { position = "right", width = 0.45 } })
        end,
        desc = "Python REPL",
      },
      {
        "<leader>;r",
        snacks_term("pytest", { win = { position = "bottom", height = 0.4 } }),
        desc = "pytest (run all)",
      },
    },
  },
}
