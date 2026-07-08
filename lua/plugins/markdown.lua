-- LaTeX rendering in markdown buffers.
--
-- render-markdown.nvim (installed via LazyVim's lang.markdown extra) already
-- enables its `latex` component by default, converting LaTeX source to
-- Unicode via an external converter and displaying it as virtual text. This
-- file makes that dependency explicit and documented rather than relying
-- silently on upstream defaults.
--
-- Requires, in priority order (see `scripts/install-utftex.sh` for the
-- first):
--   * utftex     (bartp5/libtexprintf) - high-fidelity: real superscripts,
--                stacked fractions, rendered matrices. Run
--                `./scripts/install-utftex.sh` to build and install it.
--   * latex2text (pylatexenc) - fallback for anything utftex can't parse.
--     `uv tool install pylatexenc`
--
-- Both binaries end up on PATH via ~/.local/bin. Neither is required for
-- Neovim to start; without them the latex component just stays inactive
-- (see `:checkhealth render-markdown`).

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      latex = {
        enabled = true,
        converter = { "utftex", "latex2text" },
        inline = true,
        block = true,
      },
    },
  },
}
