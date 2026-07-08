# LaTeX rendering in markdown files

## Goal

Render LaTeX math (`$inline$` and `$$block$$`) inline in Neovim markdown buffers, by default, with no manual toggle required.

## Background

`render-markdown.nvim` is already installed via LazyVim's `lang.markdown` extra and already has its `latex` component `enabled = true` by default. It converts LaTeX source to Unicode text by shelling out to an external converter and displaying the result as virtual text/lines — it does no rendering itself. The default converter list is `{ 'utftex', 'latex2text' }`: it tries `utftex` first, and falls back to `latex2text` only for formulas `utftex` can't handle. Neither binary is currently installed, so the feature is silently inactive.

Two candidate converters were evaluated directly (not just from documentation) by piping real formulas through each:

- **`latex2text`** (from the `pylatexenc` PyPI package): produces a readable but flat approximation. `\frac{a}{b}` → `a/b`, superscripts stay as `x^2` (not Unicode `x²`), matrices become bracketed rows like `[ 1 2; 3 4 ]`. Trivial to install (`uv tool install pylatexenc`), no build step.
- **`utftex`** (from the `libtexprintf` C project, github.com/bartp5/libtexprintf): produces high-fidelity output — real Unicode superscripts/subscripts (`x²`, `e⁻ˣ`), stacked fractions using box-drawing characters, multi-line rendered integrals with limits, and matrices with proper brackets. This is a much closer match to real typeset math. It has no apt/pip package and must be built from source via autotools, but the project is actively maintained (releases up to v1.31, pushed within the last few months).

Both were built/tested in this session. A static build of `utftex` (`./configure --disable-shared --enable-static`) produces a self-contained binary with no runtime library dependency beyond libc/libm, which avoids needing to manage `LD_LIBRARY_PATH` for a process Neovim shells out to.

## Approach

Install both converters, matching `render-markdown.nvim`'s own default priority order, so `utftex` handles the common case and `latex2text` is an automatic fallback for anything `utftex` can't parse. No Neovim/Lua config changes are strictly required since the defaults already enable and prioritize this correctly — but we'll add explicit config for documentation/discoverability, matching the existing convention (`jupyter.lua` documents its external Python requirements in a header comment).

### Components

1. **`scripts/install-utftex.sh`** (new) — a small, idempotent install script:
   - Clones `bartp5/libtexprintf` into a temp directory
   - Runs `./autogen.sh && ./configure --prefix="$HOME/.local" --disable-shared --enable-static`
   - Builds and installs (`make && make install`), placing the static binary at `~/.local/bin/utftex` (already on `PATH`)
   - Cleans up the temp build directory
   - Documents the one-time system dependency (`sudo apt install autoconf automake libtool build-essential`) in a comment at the top, since installing system packages requires a real terminal with sudo access and can't be scripted around that prompt

2. **`lua/plugins/markdown.lua`** (new) — a header comment documenting both external requirements (`scripts/install-utftex.sh` and `uv tool install pylatexenc`), plus an explicit `render-markdown.nvim` opts override that mirrors the current defaults for `latex` (`enabled = true`, `converter = { 'utftex', 'latex2text' }`, `inline = true`, `block = true`). This makes the dependency and intent discoverable in-repo instead of relying silently on upstream defaults that could change.

### Installation steps (one-time, this session)

1. Run `scripts/install-utftex.sh` (after the one-time `apt install` of build tools, already done in this session)
2. Run `uv tool install pylatexenc`

## Testing / verification

- Run `:checkhealth render-markdown` in Neovim and confirm the `latex` section reports a converter found (not "none installed")
- Open a scratch markdown file containing a handful of inline and block LaTeX examples (a fraction, a superscript, an integral with limits, a matrix) and visually confirm they render inline in the buffer
- Confirm normal markdown editing (typing near/inside a formula) doesn't visibly lag, since `utftex` is a fast native binary rather than a Python interpreter startup

## Out of scope

- True image-based rendering (e.g. `nabla.nvim` + `image.nvim`) was considered and explicitly deferred — continuous, always-on rendering is better served by a fast text converter than an image-compile pipeline. This can be revisited later as an on-demand addition if Unicode rendering proves insufficient for some formulas.
- No changes to `markdown-preview.nvim` (browser-based preview) — unaffected by this work.
