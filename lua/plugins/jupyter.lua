-- Inline Jupyter workflow:
--   * `.py` files with `# %%` cell markers
--   * `.ipynb` files round-trip to `# %%` via jupytext
--   * molten executes cells against a kernel; output (text + plots) renders inline
--   * quarto + otter give you full LSP/completion *inside* code cells
--
-- Requirements outside nvim:
--   * A terminal that speaks the Kitty graphics protocol (WezTerm recommended).
--   * `imagemagick` installed (`sudo apt install imagemagick`).
--   * Python `pynvim` and `jupyter_client` in the active environment:
--       uv pip install pynvim jupyter_client ipykernel
--     and a kernel registered: `python -m ipykernel install --user --name <name>`.

return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    ft = { "python", "quarto", "markdown" },
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_wrap_output = true
    end,
    keys = {
      { "<leader>j", "", desc = "+jupyter" },
      { "<leader>ji", "<cmd>MoltenInit<cr>", desc = "Init kernel" },
      { "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", desc = "Eval line" },
      { "<leader>jc", "<cmd>MoltenReevaluateCell<cr>", desc = "Re-eval cell" },
      { "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "Eval selection" },
      { "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", desc = "Enter output" },
      { "<leader>jh", "<cmd>MoltenHideOutput<cr>", desc = "Hide output" },
      { "<leader>jr", "<cmd>MoltenRestart!<cr>", desc = "Restart kernel" },
      { "<leader>jd", "<cmd>MoltenDelete<cr>", desc = "Delete cell output" },
      { "<leader>jq", "<cmd>MoltenInterrupt<cr>", desc = "Interrupt kernel" },
    },
  },

  -- Open .ipynb as a `# %%`-delimited Python buffer; save back to .ipynb.
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      style = "percent",
      output_extension = "py",
      force_ft = "python",
    },
  },

  -- Image rendering backend for molten and markdown.
  {
    "3rd/image.nvim",
    -- The luarocks build path needs `magick` (luarock) + imagemagick on PATH.
    -- Using `processor = "magick_cli"` lets us skip the luarock and use the
    -- `magick` CLI directly, which is much easier to install on WSL.
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "quarto" },
        },
      },
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },

  -- Quarto + otter: LSP/completion inside `# %%` code blocks of .qmd and
  -- markdown-style notebooks. Activate per-buffer with :QuartoActivate.
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      lspFeatures = {
        languages = { "python" },
        chunks = "all",
        diagnostics = { enabled = true, triggers = { "BufWritePost" } },
        completion = { enabled = true },
      },
      codeRunner = {
        enabled = true,
        default_method = "molten",
      },
    },
  },
}
