-- Terminal keymaps backed by snacks.nvim (already loaded by LazyVim).
--
-- Layout:
--   <C-/>          toggle the project-root terminal (provided by LazyVim)
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
    opts = {
      terminal = {
        win = {
          keys = {
            -- Snacks defaults to a double escape. A single escape makes the
            -- normal-mode window and buffer mappings immediately available.
            term_normal = {
              "<Esc>",
              function()
                vim.cmd.stopinsert()
              end,
              mode = "t",
              desc = "Enter Terminal-Normal mode",
            },
          },
        },
      },
    },
    keys = {
      { "<leader>;", "", desc = "+terminal" },
      { "<leader>;t", snacks_term(nil, { win = { position = "float" } }), desc = "Terminal (float)" },
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
        snacks_term({ "uv", "run", "pytest" }, { win = { position = "bottom", height = 0.4 } }),
        desc = "pytest (run all)",
      },
      {
        "<leader>;l",
        snacks_term({ "uv", "run", "pytest", "--no-cov", "-m", "live", "-s", "tests/live" }, {
          env = { PERSISTRA_RUN_LIVE = "1" },
          win = { position = "bottom", height = 0.4 },
        }),
        desc = "pytest (run live suite)",
      },
    },
  },
}
