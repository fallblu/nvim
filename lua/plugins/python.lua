-- Python-specific overrides on top of `lazyvim.plugins.extras.lang.python`.
-- The extra already wires pyright + ruff LSP, conform ruff_format on save,
-- venv-selector, and nvim-dap-python. We only add what's missing or different.

return {
  -- Make pyright defer linting/import-sorting to ruff and run only type checks.
  -- Avoids duplicate diagnostics between pyright and ruff.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            pyright = { disableOrganizeImports = true },
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoImportCompletions = true,
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
      },
    },
  },

  -- Mason: make sure the tools are installed even outside a project venv.
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "pyright", "ruff", "debugpy" } },
  },

  -- venv-selector: a manual override picker. Auto-detection of `.venv` at
  -- project root is already on by default in the LazyVim extra.
  {
    "linux-cultist/venv-selector.nvim",
    optional = true,
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
    },
  },
}
