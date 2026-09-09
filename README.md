# Neovim workflow

This is a focused Neovim configuration for Python, OCaml, Agda, pytest, Codex,
tmux, and embedded terminals. Navigation is picker-first, Hardtime applies
recoverable training constraints, and Precognition displays contextual motion
hints. The language workflows resolve tools and roots per project and keep
long-running jobs isolated from ordinary build directories. Snacks image
handling is explicitly disabled, so image files are not intercepted or
rendered inside Neovim.

## Dashboard and appearance

Starting Neovim without a file opens a custom dashboard with project search,
recent files and projects, session restore, configuration access, theme
selection, and plugin management. It also shows the current working directory
so the dashboard's project context is explicit.

Kanagawa Wave is the default colorscheme. Press `<leader>uC`, or `t` from the
dashboard, to browse the curated dark colorschemes with live preview. `<Esc>`
restores the previous theme; `<Enter>` applies the highlighted theme and saves
it for future sessions. The selection includes Kanagawa, Catppuccin, Tokyo
Night, Rosé Pine, Gruvbox, Nightfox, Everforest, and Oxocarbon variants.

## Navigate directly

| Goal | Command |
| --- | --- |
| Find a project file | `<leader><space>` |
| Choose an open buffer | `<leader>,` |
| Return to the alternate buffer | `<leader>bb` |
| Search project text | `<leader>/` |
| Jump to a visible location | `s` (Flash) |
| Jump to a definition or references | `gd` / `gr` |
| Jump through history | `<C-o>` / `<C-i>` |
| Move half a screen | `<C-u>` / `<C-d>` |
| Move to screen top, middle, or bottom | `H` / `M` / `L` |

Use `f`, `F`, `t`, and `T` for a known character on the current line; repeat
with `;` and reverse with `,`. Prefer a count such as `5j` to repeated presses.

Precognition shows the destinations for motions such as `w`, `b`, `e`, `{`,
`}`, `0`, and `$` as virtual text in Normal mode. It hides its hints while
inserting text and in transient plugin buffers. Toggle it with `<leader>uP`.

## Edit with operators

Build edits as an operator followed by a motion or text object:

| Instead of selecting first | Use |
| --- | --- |
| Select a word, then replace it | `ciw` |
| Select inside quotes, then replace it | `ci"` |
| Select a paragraph, then delete it | `dap` |
| Select a function, then copy it | `yaf` |
| Select inside a function, then indent it | `>if` |
| Select inside a class, then replace it | `cic` |

`mini.ai` supplies the `f` function, `c` class, and `o` block text objects.
Normal-mode `v` and `V` are disabled during training; blockwise `<C-v>` remains
available. Press `<Esc>` to leave Insert mode.

Hardtime blocks rapid repeated motions, including repeated `w`, but never
forces an exit from Insert mode. Snacks interfaces are exempt so picker and
terminal interaction remains natural. Use `<leader>uH` or `:Hardtime toggle`
for an intentional escape hatch, and `:Hardtime report` to review recurring
habits.

## Diagnostics and spelling

Diagnostics remain active, but only warnings and errors on the cursor line show
inline text. Signs and warning/error underlines remain visible. Use `[d` / `]d`
to move between diagnostics and `<leader>cd` to open the full message.

Spell-checking is active in prose, commit messages, Python comments/docstrings,
and Agda comments. Use `[s` / `]s` to move between misspellings, `z=` for
suggestions, and `zg` to accept a word.

## Tests and terminals

Neotest uses `<leader>tr` for the nearest test, `<leader>tt` for the current
file, and `<leader>tl` for the last run. `<C-/>` toggles the primary
project-root terminal. Each custom layout has a separate persistent identity,
so opening one no longer moves the same shell between unrelated layouts:

| Goal | Key |
| --- | --- |
| Floating shell | `<leader>;t` |
| Bottom split shell | `<leader>;s` |
| Right split shell | `<leader>;v` |
| Project Python REPL | `<leader>;p` |
| Run the project pytest suite | `<leader>;r` |
| Run `tests/live` with `PERSISTRA_RUN_LIVE=1` | `<leader>;l` |
| Open Lazygit, when installed | `<leader>;g` |

Python terminals prefer the environment selected by venv-selector, then a
`uv.lock` project, and finally an available system interpreter. The live-suite
mapping is available globally but refuses to run unless the current project
contains `tests/live`.

Inside a terminal, press `<Esc>` twice within 200 ms to enter Terminal-Normal
mode. A single escape is still delivered to the process. In Terminal-Normal
mode, `q` hides the terminal and `<leader>,` opens the buffer picker.
`<C-h>`, `<C-j>`, `<C-k>`, and `<C-l>` move directly between split windows and
continue into adjacent tmux panes from Terminal mode.

## Codex and tmux

Sidekick runs the installed official `codex` CLI in a right-hand terminal. Its
session is backed by tmux, so hiding the window or restarting Neovim does not
discard the conversation. Copilot next-edit suggestions are disabled; this
integration uses Codex only.

| Goal | Key |
| --- | --- |
| Toggle Codex | `<leader>aa` |
| Focus Codex from another window | `<C-.>` |
| Send the current context | `<leader>at` |
| Send the current file | `<leader>af` |
| Send a visual selection | `<leader>av` |
| Choose and send a prepared prompt | `<leader>ap` |
| Detach the Codex session | `<leader>ad` |

Inside the Codex terminal, `<C-.>` hides the window, `<C-z>` returns to the
previous window without hiding it, and `<C-p>` opens the same prompt/context
picker. Run `:Sidekick cli show name=codex` when command-line access is more
convenient.

Normal-mode `<C-h>`, `<C-j>`, `<C-k>`, and `<C-l>` navigate seamlessly across
Neovim windows and tmux panes. Matching tmux bindings live in
`~/.config/tmux/tmux.conf`; reload an existing tmux server with
`tmux source-file ~/.config/tmux/tmux.conf`. Agda's buffer-local `<C-j>` and
`<C-k>` goal mappings continue to take precedence in Agda buffers.

## OCaml

OCaml tools are resolved through OPAM rather than Mason. The active global
switch is used by default. If an `_opam` directory is found above the current
project, that project-local switch is selected automatically. Install the
editor and workflow tools in every switch used for development:

```sh
opam install dune ocaml-lsp-server ocamlformat ocp-indent odoc utop
```

OCaml LSP supplies completion, navigation, diagnostics, code actions, semantic
highlighting, and signature help. `<localleader>i` switches between a `.ml`
implementation and its `.mli` interface. OCamlFormat runs on save for OCaml,
interface, OCamllex, and Menhir files; `dune format-dune-file` formats Dune
files. Project `.ocamlformat` files are honored, while standalone learning files
can still be formatted.

Project discovery uses the nearest `dune-project`, `dune-workspace`, `.git`, or
`.opam` marker. A valid project-local `_opam` switch takes precedence over the
active global switch. Tool results are cached for responsiveness; use
`:OcamlRefreshTools` after installing or changing switch tools.

Run `<localleader>w` early in a project to start `dune build --watch`. The
persistent terminal can be hidden with the same key from either Terminal or
Terminal-Normal mode, then reopened from an OCaml buffer. Its Dune RPC session
gives ocamllsp fresher build information. Watch builds use a project-specific
directory under Neovim's cache so the project's `_build` directory remains
available to commands in other terminals. The OCaml actions use
`<localleader>` (backslash by default):

| Goal | Key |
| --- | --- |
| Search all OCaml actions | `<localleader>a` |
| Build / toggle build watch | `<localleader>b` / `<localleader>w` |
| Run tests / an executable | `<localleader>t` / `<localleader>x` |
| Build and offer to open odoc documentation | `<localleader>d` |
| Toggle the project UTop | `<localleader>r` |
| Send phrase / visual selection | `<localleader>s` |
| Send line / saved file | `<localleader>l` / `<localleader>f` |
| Switch implementation/interface | `<localleader>i` |

Inside a Dune project, the REPL runs `dune utop`; elsewhere it runs plain
`utop`. Sending a phrase uses the top-level Tree-sitter node under the cursor,
and sending a file saves it before evaluating it with `#use`. UTop terminals are
persistent and separate for each project. Project REPL builds use a dedicated
directory under Neovim's cache, so they can run independently of the watcher
and commands using the project's `_build` directory. Exiting UTop closes its
terminal automatically. The REPL opens in a bottom split. Hiding it with `q` or
`<localleader>r` keeps the process running; deleting the terminal buffer stops
it.

The same actions are available as commands: `:OcamlActions`, `:OcamlBuild`,
`:OcamlWatch`, `:OcamlTest`, `:OcamlExec`, `:OcamlDocs`, `:OcamlUtop`,
`:OcamlSendPhrase`, `:OcamlSendLine`, `:OcamlSendFile`, and
`:OcamlSwitchImplIntf`. `:OcamlBuild`, `:OcamlTest`, and `:OcamlExec` accept
optional arguments; invoking `:OcamlExec` without arguments opens a prompt.
Failed documentation builds populate a navigable quickfix list.
`:OcamlCleanCache` removes this project's Neovim-owned watcher and UTop build
directories after confirmation; `:OcamlCleanCache!` removes all such caches.

## Agda

Cornelis is pinned to v2.8.0 to match the Agda 2.8 toolchain. Ordinary and
literate Agda filetypes share the same mappings, spelling rules, and committed
input method. The Agda Tree-sitter parser is installed for syntax-aware
highlighting of ordinary Agda source.

Completion is explicit: `<Enter>` always inserts a newline and `<C-y>` accepts
the selected completion. In an Agda buffer, `<C-Space>` opens a searchable
Unicode reference in both Normal and Insert mode. Entries show their complete
input sequence, so `∷`, for example, is `\::<Tab>`. Choosing an entry inserts
it and leaves the buffer in Insert mode. `:AgdaUnicode` opens the same picker.
Because Agda reserves `<C-Space>` and `<C-k>`, `<C-g>c` opens normal completion
and `<C-g>s` opens signature help from Insert mode.

Use `<C-j>` / `<C-k>` from either Normal or Insert mode to jump to the next or
previous goal, center it, and continue in Insert mode. `[g` / `]g` provide
centered Normal-mode navigation without changing modes. `<localleader>p` or
`:AgdaActions` opens a searchable list of every configured Cornelis action.

The most common direct actions use `<localleader>` (backslash by default):

| Goal | Key |
| --- | --- |
| Load and type-check | `<localleader>l` |
| Give / refine / elaborate | `<localleader>g` / `<localleader>r` / `<localleader>e` |
| Case split / auto / solve | `<localleader>c` / `<localleader>a` / `<localleader>s` |
| Type and context / infer type | `<localleader>t` / `<localleader>i` |
| Normalize | `<localleader>n` |
| Show all goals | `<localleader>?` |
| Expand `?` into a goal | `<localleader>q` |
| Abort / restart Cornelis | `<localleader>A` / `<localleader>R` |
| Compile / compile and run | `<localleader>b` / `<localleader>x` |

Files load and type-check automatically 200 ms after the latest save, preventing
rapid saves from queuing redundant reloads. Compilation runs from the nearest
`.agda-lib` or Git project root, cancels an older compile when a new one starts,
and populates quickfix with navigable Agda or GHC diagnostics. Compile-and-run
uses the executable path reported by GHC rather than guessing its location.

## Maintenance

Run the complete local validation suite from this directory:

```sh
./scripts/check
```

The command checks shell syntax and whitespace, verifies Lua formatting with
StyLua, runs Lua Language Server diagnostics, executes the headless smoke
tests, and fails on configuration health errors. It finds StyLua and LuaLS on
`PATH` or in Mason. Set `NVIM_BIN` to test with a non-default Neovim binary.

Use `:checkhealth garrett` interactively for the same environment-oriented
report. It covers core executables, workflow plugins, Codex/tmux integration,
Tree-sitter parsers, Python command selection, the active OPAM switch,
Agda/Cornelis tools, and the WSL clipboard fallback. Optional integrations such
as Lazygit are reported without treating their absence as a broken
configuration.
