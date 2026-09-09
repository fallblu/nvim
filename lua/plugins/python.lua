-- Python-specific language overrides. The base integration already wires
-- pyright, Ruff's native LSP formatter, and
-- venv-selector. We only add what's missing or different.

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
                typeCheckingMode = "standard",
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
    opts = { ensure_installed = { "pyright", "ruff" } },
  },
}
