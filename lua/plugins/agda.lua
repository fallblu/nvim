return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "agda" })
    end,
  },

  {
    "agda/cornelis",
    -- Cornelis v2.8.0 matches the installed Agda 2.8 toolchain.
    commit = "deda7eb399efe94cc49c645da7b6f94780fe0c19",
    ft = require("config.filetypes").agda,
    build = "stack --system-ghc install",
    dependencies = {
      "neovimhaskell/nvim-hs.vim",
      "kana/vim-textobj-user",
    },
    init = function()
      local ghcup_bin = vim.fn.expand("~/.ghcup/bin")
      if not vim.env.PATH:find(ghcup_bin, 1, true) then
        vim.env.PATH = ghcup_bin .. ":" .. vim.env.PATH
      end

      -- Cornelis normally asks nvim-hs to build a per-plugin binary. Lazy's
      -- build step installs the pinned binary once in ~/.local/bin instead.
      vim.g.cornelis_use_global_binary = 1

      -- Populate our explicit, Tab-committed input table instead of creating
      -- thousands of overlapping insert-mode mappings.
      vim.g.cornelis_bind_input_hook = "CornelisAgdaInputHook"
      vim.cmd([[
        function! CornelisAgdaInputHook(key, character) abort
          call luaeval("require('config.agda_input').register(_A[1], _A[2])", [a:key, a:character])
        endfunction
      ]])
      require("config.agda_input").setup()
    end,
    config = function()
      require("config.agda").setup()
    end,
  },
}
