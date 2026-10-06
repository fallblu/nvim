# Neovim, one step at a time

A small configuration for Python and C++ development and editing Lua configuration.
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
prefix. Try **Space** for this configuration's shortcuts, **Space w** for
window commands, or **g r** for LSP actions. Keep typing when you
already know a sequence; there is no need to wait for the popup.

Leader groups are **c** for code, **d** for debugging, **m** for C++ programs,
**p** for Python, **s** for search, **t** for terminals, **u** for editing toggles,
and **w** for windows.
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
**Ctrl+v** opens a file/buffer in a vertical split, and **Ctrl+x** opens it in
a horizontal split. **Ctrl+t** opens in a new tab page. The footer reminds you
of the split keys; **Shift+Tab** shows all picker keys. Ctrl+x replaces the old
Ctrl+s picker binding, which some terminals intercept for flow control.
These split actions also work on project text search results.
**Ctrl+k** marks or unmarks a result and **Ctrl+a** marks them all;
**Alt+Enter** then sends the marked files or search matches to the quickfix
list, where `]q` and `[q` step through them.

## Python, C++, and Lua language support

Lua Language Server starts automatically for Lua files and learns Neovim's
API when editing this configuration. Other Lua projects retain their own
server settings. Python uses Basedpyright for completions, documentation,
navigation, refactoring, and basic type checking, plus Ruff for linting and
code actions. Both use the current file's project root; Basedpyright detects
its `.venv/bin/python`. Project type-checking settings can override the basic
default. C++ uses clangd for the same features, with learncpp's recommended
warnings (`-Wall -Wextra -Wconversion -Wsign-conversion -Wshadow
-pedantic-errors`) and clang-tidy checks; `.h` files count as C++. Diagnostics
show signs and underlines; the cursor line's messages appear at its end, and
nothing pops up while typing. Neovim's LSP
client exposes these actions:

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
| Space c D | List diagnostics from loaded files in the quickfix list |
| Space c r / Space c a | Rename / code actions (aliases for grn / gra) |
| Space c o | Organize Python imports explicitly with Ruff |
| Space c h | Switch between a C++ source file and its header |
| Ctrl+s or Ctrl+g, s (Insert mode) | Show function parameters/signature |
| Space u h | Toggle inlay type/parameter hints, when supported (initially off) |
| Space u d | Toggle diagnostics for this buffer |

Multiple definition/reference results use Neovim's quickfix list. Use
`:copen` to inspect it, `:cnext` / `:cprevious` to visit results, and `:cclose`
to close the list. Symbol listings use the location list (`:lopen`).

### Completion without accidental acceptance

Blink completion offers LSP results, paths, snippets, and fallback buffer words.
The menu appears after typing, with a short delay. Nothing is preselected;
selecting an item previews it inline without changing the buffer. A documentation
panel shows the selected item's available type information and documentation.
The menu includes item kinds and sources and works without a Nerd Font.

| Insert-mode keys | Action |
| --- | --- |
| Ctrl+Space | Request completion / show or hide selected-item documentation |
| Ctrl+n / Ctrl+p | Select next / previous suggestion |
| Enter | Accept the explicitly selected suggestion; otherwise insert a newline |
| Ctrl+e / Esc | Dismiss suggestions / leave Insert mode |
| Ctrl+f / Ctrl+b | Scroll completion documentation down / up |
| Tab / Shift+Tab | Next / previous placeholder inside an accepted snippet |

**Enter accepts only after you select a suggestion with Ctrl+n / Ctrl+p.**
With nothing selected, Enter inserts a newline with paired indentation.
Tab, ordinary typing, and moving the cursor never accept suggestions. Tab indents
normally outside an active snippet. Accepting an auto-import suggestion with Enter can
add its import; merely browsing it cannot. Function completions do not append
parentheses automatically: type `(` to start a call. Accepting a C++ standard
library name can add its `#include` the same way. Inline previews come from the
completion sources above, without an AI service.

**Space u c** switches this buffer between automatic menus and manual-only
completion; Ctrl+Space works in either mode. Command-line and terminal
completion keep their native behavior. If Ctrl+Space is intercepted by your
terminal, Ctrl+n also opens the menu. Ctrl+g followed by s requests signature
help without relying on the terminal's handling of Ctrl+s.

Use `:checkhealth vim.lsp` to inspect attached clients and server availability.

### Pairs and indentation

Opening parentheses, brackets, braces, and quotes insert their closing pair.
Type the closing character to move over it; Backspace between an empty pair
removes both characters. Python triple quotes are supported. Enter inside an
empty bracket pair creates an indented line and moves the closer below it:

```python
values = [
    # cursor starts here
]
```

Python uses four spaces for blocks and hanging indents, including nested
lists/dictionaries and multiline calls. Closing delimiters on their own line
align with their opening statement. C++ also uses four spaces, with `case`
labels level with their `switch`, access specifiers level with their class,
and unindented namespace contents. `==` reindents a line; `=` in Visual mode
reindents a selection. Visual `<` / `>` keep the selection for repeated shifts.
**Space u p** toggles automatic pairing globally. Paste retains Neovim's native
paste handling. Esc in Normal mode also clears search highlighting.

## Python and uv

Tests, scripts, and REPLs use the project's `.venv/bin/python`, as does Python
language analysis when that environment exists. Opening a file does not run `uv sync` or change
dependencies. For a new checkout, prepare its environment using that project's
documented uv command. Restart Neovim after recreating an environment or
changing its tools.

Python files format with Ruff on save, using the project's installed Ruff and
configuration through Conform. This uses the Ruff command-line formatter.

| Keys | Action |
| --- | --- |
| Space c f / Space c F | Format / toggle format on save for this buffer |
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

## C++ programs

g++, make, gdb, Bear, and Valgrind come from Ubuntu packages; clangd,
clang-format, and the codelldb debug adapter come from Mason. Make runs
through Bear, which records compile commands for clangd. C++ files format with clang-format on
save, using the project's `.clang-format` or the shared
`styles/clang-format.yaml`; Space c f and Space c F work as for Python.

| Keys | Action |
| --- | --- |
| Space m b | Build: make in the nearest Makefile directory, else g++ for this file |
| Space m r / Space m R | Build and run the program below, without / with arguments |
| Space m v / Space m V | Build without sanitizers and run under Valgrind, without / with arguments |
| Space m p | Choose the program to run or debug when make builds something else |
| Space m m | Run a make target such as `clean` |
| Space m q | Show / hide the build diagnostics list |
| `]q` / `[q` | Next / previous build diagnostic |
| Space m k | Manual page for the word under the cursor |
| Space d b / Space d c | Toggle breakpoint / build and debug the program |
| Space m h | Open the C++ workflow guide |

Without a Makefile, a file compiles alone with warnings, debug information,
and the address and undefined-behavior sanitizers, which report memory
mistakes as the program runs. Use **Space m h** for the full
[C++ guide](docs/cpp.md), including debugging and starting a practice project.

## Windows and buffers

A buffer holds file contents; a window displays a buffer. Several windows
can display the same buffer. A tmux pane contains a running terminal process.

| Keys or command | Action |
| --- | --- |
| Space \| / Space - | Split the current view vertically / horizontally |
| Space w v / Space w s | The same split actions under the window menu |
| `:vsplit path` / `:split path` | Open a specific file in a split |
| Ctrl+h / Ctrl+j / Ctrl+k / Ctrl+l | Focus a window in that direction (Normal mode) |
| Space w H / J / K / L | Move the current window to that outer edge |
| Space w = | Equalize window sizes |
| Ctrl+Up / Ctrl+Down | Increase / decrease height |
| Ctrl+Right / Ctrl+Left | Increase / decrease width |
| Space w d | Close the current window; unsaved changes remain protected |
| Space w o | Keep only the current window |
| Space w w | Focus the next window |
| Space , | Choose a buffer to display in the current window |
| `[b` / `]b` | Previous / next buffer |
| Ctrl+Shift+6 | Return to the alternate buffer on US QWERTY |
| `:bdelete` | Delete the current buffer; may close its window |

All native Ctrl+w commands remain available. Uppercase movement keys require
Shift. These mappings act on Neovim windows, not tmux panes.
See `:help windows` for details.

## Project terminals

**Space t t** creates a new project shell below the current window.
**Space t v** creates one to the right. Each invocation creates a new shell.
Terminals inherit the current file's project root, including when another
project terminal is the current buffer.

Press **Esc twice** to enter Terminal-Normal mode. The native alternative is
**Ctrl+\ then Ctrl+n**, and avoids the mapping's delay for a single Escape.
You can then use Ctrl+h/j/k/l or Space w window commands, Space , to choose a buffer, or `i`
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
| `lua/config/lsp.lua` | Python/C++/Lua language servers, diagnostics, and LSP actions |
| `lua/config/completion.lua` | Explicit completion acceptance, documentation, and previews |
| `lua/config/pairs.lua` | Automatic pairs and safe Enter behavior |
| `lua/config/keymaps.lua` | Window, buffer, and general editing shortcuts |
| `lua/config/format.lua` | Python and C++ formatting and the per-buffer save toggle |
| `lua/config/python.lua` | Pytest targets, file execution, and project REPLs |
| `lua/config/cpp.lua` | C++ builds, program runs, make targets, and manual pages |
| `after/ftplugin/cpp.lua` | C++ indentation settings |
| `styles/clang-format.yaml` | C++ formatting style for projects without `.clang-format` |
| `templates/cpp/` | Multi-file C++ Makefile and an exercise repository `.gitignore` |
| `lua/config/debug.lua` | Debug adapter, launch choices, and debugger controls |
| `lua/config/terminal.lua` | Creating embedded project shells |
| `scripts/work` | Creating/resuming project tmux sessions |
| `scripts/repl.py` | Receiving selected code in an ordinary Python interpreter |
| `lazy-lock.json` | Exact plugin revisions |

Plugins include [Kanagawa](https://github.com/rebelot/kanagawa.nvim),
[Mini Pick](https://github.com/nvim-mini/mini.pick),
[Mini Statusline](https://github.com/nvim-mini/mini.statusline),
[Which-key](https://github.com/folke/which-key.nvim),
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig),
[Mason](https://github.com/mason-org/mason.nvim),
[Conform](https://github.com/stevearc/conform.nvim),
[Blink completion](https://cmp.saghen.dev/configuration/completion),
[Friendly Snippets](https://github.com/rafamadriz/friendly-snippets),
[nvim-autopairs](https://github.com/windwp/nvim-autopairs),
[vim-test](https://github.com/vim-test/vim-test), and
[nvim-dap](https://github.com/mfussenegger/nvim-dap).
[lazy.nvim](https://github.com/folke/lazy.nvim) manages them. This setup uses
neither the LazyVim distribution nor its automatic feature imports.
The UI works with a standard terminal font; a Nerd Font is optional.
The debugger is pinned to a revision compatible with Neovim 0.11.6; its newer
development branch requires Neovim 0.11.7 or later.

Use `:Lazy` to inspect plugins and explicitly update them; `:Lazy restore`
restores locked revisions. Use `:Mason` for standalone language servers,
formatters, and debug adapters. On another machine, install Neovim 0.11.3+,
Git, ripgrep, uv, and the C++ toolchain (Ubuntu: `build-essential`, `gdb`,
`manpages-dev`, `bear`, `valgrind`, and optionally `libstdc++-15-doc`); launch once to install plugins, then
run:

```vim
:MasonInstall lua-language-server basedpyright ruff debugpy clangd clang-format codelldb
```

The current machine already has these tools installed. Restart Neovim after
configuration changes to load the new plugins, mappings, and language servers.

To check editing behavior after changes, run `python3 tests/editor_workflow.py`
from this directory (requires the Python `pynvim` package). It launches a separate
Neovim instance and uses temporary files and a temporary Python environment to
exercise pairing, indentation, completion acceptance, Python and C++ language
support, formatting, C++ builds, runs, and Valgrind checks, and window/picker
actions. It does not edit project files.
