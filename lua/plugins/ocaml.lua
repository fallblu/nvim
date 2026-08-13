local ocaml = require("config.ocaml")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "ocaml_interface", "ocamllex", "menhir" })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    init = function()
      -- Give each OCaml grammar its own filetype. This lets Tree-sitter select
      -- the interface, lexer, and Menhir parsers while ocamllsp still handles
      -- every file through its standard language-id adapter.
      vim.filetype.add({
        extension = {
          mli = "ocamlinterface",
          mll = "ocamllex",
          mly = "menhir",
        },
      })
      require("config.ocaml_workflow").setup()
    end,
    opts = {
      servers = {
        ocamllsp = {
          mason = false,
          filetypes = { "ocaml", "ocamlinterface", "ocamllex", "menhir", "reason", "dune" },
          cmd = function(dispatchers)
            local root = ocaml.root(vim.api.nvim_buf_get_name(0))
            local command = ocaml.opam_command("ocamllsp", nil, root)
            return vim.lsp.rpc.start(command, dispatchers, { cwd = root })
          end,
        },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ocaml = { "ocamlformat" },
        ocamlinterface = { "ocamlformat" },
        ocamllex = { "ocamlformat" },
        menhir = { "ocamlformat" },
        dune = { "format-dune-file" },
      },
      formatters = {
        ocamlformat = function(bufnr)
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local root = ocaml.root(filename)
          return {
            command = "opam",
            prepend_args = ocaml.opam_prefix("ocamlformat", root),
            cwd = function()
              return root
            end,
          }
        end,
        ["format-dune-file"] = function(bufnr)
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local root = ocaml.root(filename)
          return {
            command = "opam",
            prepend_args = ocaml.opam_prefix("dune", root),
            cwd = function()
              return root
            end,
          }
        end,
      },
    },
  },
}
