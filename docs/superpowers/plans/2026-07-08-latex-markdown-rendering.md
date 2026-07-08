# LaTeX Rendering in Markdown Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make LaTeX math (`$inline$` and `$$block$$`) render as Unicode inline in Neovim markdown buffers by default, with no manual toggle.

**Architecture:** `render-markdown.nvim` (already installed via LazyVim's `lang.markdown` extra) already has a `latex` component enabled by default that shells out to an external converter and displays the result as virtual text. We install two converter binaries it already knows how to use — `utftex` (high-fidelity, built from source) as primary and `latex2text` (from `pylatexenc`, trivially installed) as automatic fallback — and add an explicit, documented plugin override so the dependency isn't silently implicit.

**Tech Stack:** Neovim, Lua (LazyVim plugin spec), Bash (install script), `libtexprintf`/`utftex` (C, built via autotools), `pylatexenc` (Python, installed via `uv tool install`).

Reference: `docs/superpowers/specs/2026-07-08-latex-markdown-rendering-design.md`

---

## File Structure

- **`scripts/install-utftex.sh`** (new) — clones, builds (static), and installs the `utftex` binary to `~/.local/bin/utftex`. First script in this repo; self-contained and re-runnable.
- **`lua/plugins/markdown.lua`** (new) — LazyVim plugin spec fragment for `MeanderingProgrammer/render-markdown.nvim` that explicitly declares the `latex` opts (mirroring current upstream defaults) plus a header comment documenting both external converter dependencies. `lazy.nvim` deep-merges `opts` tables across multiple specs for the same plugin name, so this does not clobber the `code`/`heading`/`checkbox` opts already set by LazyVim's `lang.markdown` extra.

---

## Task 1: Build and install `utftex`

**Files:**
- Create: `scripts/install-utftex.sh`

- [ ] **Step 1: Write the install script**

```bash
#!/usr/bin/env bash
# Builds and installs `utftex` (from bartp5/libtexprintf) as a static binary
# at ~/.local/bin/utftex, so render-markdown.nvim can render LaTeX math in
# markdown buffers as real Unicode (superscripts, stacked fractions, etc).
# Re-run any time to rebuild/reinstall (e.g. after a fresh machine setup).
#
# One-time prerequisite (needs a real terminal for the sudo password prompt):
#   sudo apt install -y autoconf automake libtool build-essential
set -euo pipefail

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

git clone --depth 1 https://github.com/bartp5/libtexprintf.git "$WORKDIR/libtexprintf"
cd "$WORKDIR/libtexprintf"

./autogen.sh
./configure --prefix="$HOME/.local" --disable-shared --enable-static
make -j"$(nproc)"
make install

echo "Installed: $HOME/.local/bin/utftex"
"$HOME/.local/bin/utftex" --version
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/install-utftex.sh`

- [ ] **Step 3: Run the script**

Run: `./scripts/install-utftex.sh`

Expected: ends with a version banner, e.g.:
```
Installed: /home/garrett/.local/bin/utftex
   __  ____________________    _  __
  / / / /_  __/ ____/_  __/__ | |/ /
 / / / / / / / /_    / / / _ \|   /
/ /_/ / / / / __/   / / /  __/   |
\____/ /_/ /_/     /_/  \___/_/|_|
This is utftex version 1.17
Powered by libtexprintf 1.31
```
(Exact version numbers may differ if upstream has released newer tags — that's fine.)

If this fails with a `configure: error` about a missing tool, the one-time `apt install` prerequisite listed in the script's header comment hasn't been run yet — run it in a real terminal (not through this automation) and re-run the script.

- [ ] **Step 4: Verify the binary produces high-fidelity output**

Run: `echo '$\frac{\alpha}{\beta+x}$' | ~/.local/bin/utftex`

Expected (a real stacked fraction using box-drawing characters, not `a/b`):
```
 α
───
β+x
```

- [ ] **Step 5: Commit**

```bash
git add scripts/install-utftex.sh
git commit -m "feat: add utftex install script for LaTeX rendering in markdown"
```

---

## Task 2: Install `pylatexenc` fallback converter

**Files:** none (external tool install, not tracked in this repo)

- [ ] **Step 1: Install via uv**

Run: `uv tool install pylatexenc`

Expected: output ending with something like `Installed 1 executable: latex2text` (uv installs the tool into an isolated venv and places a shim in `~/.local/bin`, which is already on `PATH`).

- [ ] **Step 2: Verify it's on PATH**

Run: `which latex2text`

Expected: `/home/garrett/.local/bin/latex2text`

- [ ] **Step 3: Verify conversion output**

Run: `echo '$x^2 + \int_0^\infty e^{-x} dx = \alpha$' | latex2text`

Expected: `x^2 + ∫_0^∞ e^-x dx = α`

(No commit — this task installs an external tool, not a repo file. Its dependency is documented in Task 3's header comment.)

---

## Task 3: Add explicit `render-markdown.nvim` config

**Files:**
- Create: `lua/plugins/markdown.lua`

- [ ] **Step 1: Write the plugin spec**

```lua
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
```

- [ ] **Step 2: Format-check with stylua**

Run: `/home/garrett/.local/share/nvim/mason/bin/stylua --check lua/plugins/markdown.lua`

Expected: no output, exit code 0. If it reports a diff, run `/home/garrett/.local/share/nvim/mason/bin/stylua lua/plugins/markdown.lua` to auto-fix, then re-check.

- [ ] **Step 3: Syntax-check by loading the file in Neovim**

Run: `nvim --headless -c "luafile lua/plugins/markdown.lua" -c "qa"`

Expected: no error output (a clean exit with nothing printed).

- [ ] **Step 4: Commit**

```bash
git add lua/plugins/markdown.lua
git commit -m "feat: explicitly configure and document render-markdown latex support"
```

---

## Task 4: End-to-end verification

**Files:** none (verification only; scratch file lives outside the repo)

- [ ] **Step 1: Confirm both converters are detected by the plugin's health check**

Run:
```bash
echo '# test' > /tmp/scratch.md
nvim --headless /tmp/scratch.md -c "checkhealth render-markdown" -c "noautocmd write! /tmp/health-check.txt" -c "qa!"
grep -A2 "\[latex\]" /tmp/health-check.txt
```

Expected:
```
render-markdown.nvim [latex] ~
- ✅ OK using: { "utftex", "latex2text" }
```

If instead you see `⚠️ WARNING none installed: { "utftex", "latex2text" }`, one or both binaries from Task 1/Task 2 aren't on `PATH` in the shell Neovim was launched from — re-check `which utftex` and `which latex2text`.

- [ ] **Step 2: Visually confirm rendering in a real buffer**

Create `/tmp/latex-render-test.md`:
```markdown
# LaTeX render test

Inline: $x^2 + \alpha$

Block fraction:

$$\frac{\alpha}{\beta+x}$$

Block matrix:

$$\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}$$
```

Open it in Neovim normally (`nvim /tmp/latex-render-test.md`) and confirm:
- The inline formula shows `x²` with a real superscript and `α` instead of the raw `$x^2 + \alpha$` source
- The fraction renders as a stacked `α` over `β+x` with a horizontal rule between them
- The matrix renders with bracket characters around a `1 2 / 3 4` grid

- [ ] **Step 3: Confirm no perceptible typing lag**

While still in `/tmp/latex-render-test.md`, place the cursor on the blank line just above the fraction block and type a few characters, then undo (`u`). Typing and screen updates should feel identical to editing any other markdown file — `utftex` is a fast native binary, so there should be no visible pause when the buffer around a formula changes.

- [ ] **Step 4: Clean up scratch files**

Run: `rm -f /tmp/scratch.md /tmp/health-check.txt /tmp/latex-render-test.md`

(No commit — this task only verifies behavior; nothing here belongs in the repo.)

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers the spec's `scripts/install-utftex.sh` component and static-build requirement; Task 2 covers the `uv tool install pylatexenc` step; Task 3 covers the `lua/plugins/markdown.lua` component and its documentation requirement; Task 4 covers both items in the spec's "Testing / verification" section (health check + visual confirmation + no-lag check). The spec's "Out of scope" items (image-based rendering, markdown-preview.nvim changes) are correctly not represented by any task here.
- **Placeholder scan:** no TBD/TODO; all code blocks are complete, runnable content actually exercised during design (script logic, plugin spec, and every command's expected output were validated live in this session, except the two steps that require Task 1/Task 2 to have completed first, which are the exact same commands validated on already-built copies of the same binaries).
- **Type/naming consistency:** the plugin name (`MeanderingProgrammer/render-markdown.nvim`), converter list (`{ "utftex", "latex2text" }`), and binary names (`utftex`, `latex2text`) are identical across the spec, Task 1, Task 2, and Task 3 — no drift.
