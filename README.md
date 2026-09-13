# Neovim, one step at a time

A small configuration for Python development and editing Lua configuration.
Kanagawa Dragon supplies the colors; relative line numbers remain enabled.
Neovim's native motions and window controls remain available.

## Launch

From a project directory:

```sh
nvim
```

This is the main configuration at `~/.config/nvim`, on the `main` branch.
Plugins and language servers use Neovim's standard data directory.

Press **Space ?** inside Neovim to open this guide. Space is `<leader>` in
the configuration. Press leader sequences one key at a time.

## Discover shortcuts

Which-key shows the available next keys when you pause for 300 ms after a
prefix. Try **Space** for this configuration's shortcuts, **Ctrl+w** for
native window commands, or **g r** for LSP actions. Keep typing when you
already know a sequence; there is no need to wait for the popup.

Leader groups are **c** for code, **d** for debugging, **p** for Python,
**s** for search, and **t** for terminals.
The popup uses Kanagawa's colors, a rounded border, and plain key labels.
Press **Esc** to cancel; **Backspace** goes up one level. **Space ?** still
opens this guide. For detailed plugin help, use `:help which-key.nvim`.

## Find your way around

| Keys | Action |
| --- | --- |
| Space Space | Find a project file by name |
| Space / | Search text throughout the project |
| Space , | Choose an open buffer, including terminals |
| Space s h | Search Neovim and installed plugin help |

File/text searches use the nearest `pyproject.toml` or Git root above the
current file, falling back to the current working directory. They respect
Git ignore rules and omit hidden files by default. The buffer picker includes
open buffers across projects. `:edit path/to/file` with Tab completion remains
useful for exact paths, hidden files, and creating a new file.

In a picker, type to filter. **Ctrl+n / Ctrl+p** move through results;
**Tab** toggles preview; **Enter** opens the selection; **Esc** cancels.
**Ctrl+v** opens a file/buffer in a vertical split, and **Ctrl+s** opens it in
a horizontal split. **Shift+Tab** shows the picker's help. These picker
shortcuts apply while the picker is open.

## Read and navigate code

Python uses Pyright and Ruff; Lua uses Lua Language Server. Servers start automatically
for their filetypes. Language servers provide code understanding; Neovim's
built-in LSP client exposes it through these actions:

| Keys | Action |
| --- | --- |
| `gd` | Go to the definition under the cursor |
| Ctrl+o / Ctrl+i | Go back / forward in the jumplist |
| `K` | Read hover documentation |
| `grr` | Find references |
| `grn` | Rename a symbol and its references |
| `gra` | Show available code actions |
| `gri` / `grt` | Go to implementation / type definition, if supported |
| `gO` | List symbols in the current file |
| `[d` / `]d` | Previous / next diagnostic |
| Space c d | Read the diagnostic at the cursor |

Multiple definition/reference results use Neovim's quickfix list. Use
`:copen` to inspect it, `:cnext` / `:cprevious` to visit results, and `:cclose`
to close the list. Symbol listings use the location list (`:lopen`).

In Insert mode, completion appears on server trigger characters such as `.`.
Press **Ctrl+Space** to request it explicitly, **Ctrl+n / Ctrl+p** to select,
**Ctrl+y** to accept, or **Ctrl+e** to dismiss. Enter keeps its native behavior.
This is native LSP completion, without a separate completion plugin.

### Python and uv

Each project uses its own `.venv/bin/pyright-langserver` when present, with
Mason's Pyright as a standalone fallback. The interpreter is the project's
`.venv/bin/python`. Settings in `pyproject.toml` and `pyrightconfig.json`
remain authoritative for project analysis.

Persistra and Trading Engine both declare Pyright in their development
dependencies and configure `.venv` in `pyproject.toml`. Their existing
environments are used directly. Opening a file does not run `uv sync` or
change dependencies. For a new checkout, prepare its environment using that
project's documented uv command before editing. Restart Neovim after
recreating an environment or changing its tools.

Python files format with Ruff on save, using the project's installed Ruff and
configuration. Import organization and lint fixes run only when requested.

| Keys | Action |
| --- | --- |
| Space c f / Space c F | Format / toggle format on save for this buffer |
| Space c i / Space c x | Organize imports / apply Ruff lint fixes |
| Space p n / Space p f | Run nearest pytest test / test file |
| Space p a / Space p l | Run project tests / repeat this project's last test run |
| Space p r | Save and run the current Python file |
| Space p i | Open this project's persistent Python REPL |
| Space p s | Send current line or visual selection to the REPL |
| Space d b / Space d c | Toggle breakpoint / start or continue debugging |
| Space d n / Space d f | Debug nearest pytest test / test file |
| Space p h | Open the Python workflow guide |

Use **Space p h** for the full [Python guide](docs/python.md), including stepping,
variable inspection, and a short practice loop. Test/run/debug shortcuts save
the current Python buffer first; sending to the REPL uses the selected text
without saving. Other modified buffers keep their unsaved changes.
The ordinary `uv run` and `make` commands remain useful in project shells.

Lua Language Server learns Neovim's API when editing this configuration.
Other Lua projects retain their own server settings. Use `:checkhealth vim.lsp`
to inspect attached clients and server availability.

## Windows and buffers

A buffer holds file contents; a window displays a buffer. Several windows
can display the same buffer. A tmux pane contains a running terminal process.

| Keys or command | Action |
| --- | --- |
| Ctrl+w, v / Ctrl+w, s | Split the current view vertically / horizontally |
| `:vsplit path` / `:split path` | Open a specific file in a split |
| Ctrl+w, h / j / k / l | Focus a window in that direction |
| Ctrl+w, H / J / K / L | Move the current window to that outer edge |
| Ctrl+w, = | Equalize window sizes |
| Ctrl+w, + / - | Increase / decrease height |
| Ctrl+w, > / < | Increase / decrease width |
| Ctrl+w, c | Close the current window |
| Ctrl+w, o | Keep only the current window |
| Space , | Choose a buffer to display in the current window |
| Ctrl+Shift+6 | Return to the alternate buffer on US QWERTY |
| `:bdelete` | Delete the current buffer; may close its window |

For Ctrl+w, v, hold Control and press w, release both, then press v.
Uppercase movement keys require Shift. See `:help windows` for details.

## Project terminals

**Space t t** creates a new project shell below the current window.
**Space t v** creates one to the right. Each invocation creates a new shell.
Terminals inherit the current file's project root, including when another
project terminal is the current buffer.

Press **Esc twice** to enter Terminal-Normal mode. The native alternative is
**Ctrl+\ then Ctrl+n**, and avoids the mapping's delay for a single Escape.
You can then use Ctrl+w window commands, Space , to choose a buffer, or `i`
to return to shell input. Closing a window leaves the shell buffer available
through Space ,. Type `exit` to stop the shell; `:bdelete!` removes its buffer
and stops a shell that is still running. Embedded shells live with Neovim.

## Project tmux sessions

From an ordinary shell, use the launcher to create or resume a project:

```sh
~/.config/nvim/scripts/work ~/persistra
~/.config/nvim/scripts/work ~/trading-engine
```

With no argument it uses the current directory. A new session starts with
an editor window running this configuration and a shell window in that
project. Session names combine the directory name and a short path hash.
Re-running the command resumes the existing session and preserves its windows.
Inside tmux, the launcher switches sessions without nesting tmux.

With tmux's default bindings, press **Ctrl+b**, release, then:

| Next key | Action |
| --- | --- |
| `c` | Create another shell window |
| `p` / `n` | Previous / next window |
| `w` | Choose a window or session |
| `%` / `"` | Split a pane vertically / horizontally |
| Arrow key | Focus an adjacent pane |
| `z` | Zoom the current pane / restore the layout |
| `d` | Detach while keeping processes running |

The launcher uses your existing tmux settings and changes no tmux bindings.
See the [official tmux guide](https://github.com/tmux/tmux/wiki/Getting-Started).

## Understand and maintain the configuration

| File | Responsibility |
| --- | --- |
| `init.lua` | Editor options and startup order |
| `lua/config/plugins.lua` | Plugin installation, appearance, and pickers |
| `lua/config/project.lua` | Project root selection |
| `lua/config/lsp.lua` | Servers, project Python selection, and LSP actions |
| `lua/config/format.lua` | Python formatting and the per-buffer save toggle |
| `lua/config/python.lua` | Pytest targets, file execution, and project REPLs |
| `lua/config/debug.lua` | Debug adapter, launch choices, and debugger controls |
| `lua/config/terminal.lua` | Creating embedded project shells |
| `scripts/work` | Creating/resuming project tmux sessions |
| `scripts/repl.py` | Receiving selected code in an ordinary Python interpreter |
| `lazy-lock.json` | Exact plugin revisions |

There are nine feature plugins: [Kanagawa](https://github.com/rebelot/kanagawa.nvim),
[Mini Pick](https://github.com/nvim-mini/mini.pick),
[Mini Statusline](https://github.com/nvim-mini/mini.statusline),
[Which-key](https://github.com/folke/which-key.nvim),
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig),
[Mason](https://github.com/mason-org/mason.nvim),
[Conform](https://github.com/stevearc/conform.nvim),
[vim-test](https://github.com/vim-test/vim-test), and
[nvim-dap](https://github.com/mfussenegger/nvim-dap).
[lazy.nvim](https://github.com/folke/lazy.nvim) manages them. This setup uses
neither the LazyVim distribution nor its automatic feature imports.
The UI works with a standard terminal font; a Nerd Font is optional.
The debugger is pinned to a revision compatible with Neovim 0.11.6; its newer
development branch requires Neovim 0.11.7 or later.

Use `:Lazy` to inspect plugins and explicitly update them; `:Lazy restore`
restores locked revisions. Use `:Mason` for standalone language-server tools.
On another machine, install Neovim 0.11.3+, Git, ripgrep, Node.js, and uv;
launch once to install plugins, then run:

```vim
:MasonInstall pyright lua-language-server ruff debugpy
```

For each next increment, bring back a concrete task that felt cumbersome.
We will explain and practice its solution before expanding the configuration.
