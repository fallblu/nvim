# Neovim workflow

This is a focused LazyVim configuration for Python, Agda, pytest, and embedded
terminals. Navigation is picker-first, and Hardtime applies training constraints
that favor direct motions and operator-first edits.

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

Hardtime blocks rapid repeated motions and leaves Insert mode after ten seconds
of inactivity. Use `<leader>uH` or `:Hardtime toggle` for an intentional escape
hatch, and `:Hardtime report` to review recurring habits.

## Diagnostics and spelling

Diagnostics remain active, but only warnings and errors on the cursor line show
inline text. Signs and warning/error underlines remain visible. Use `[d` / `]d`
to move between diagnostics and `<leader>cd` to open the full message.

Spell-checking is active in prose, commit messages, Python comments/docstrings,
and Agda comments. Use `[s` / `]s` to move between misspellings, `z=` for
suggestions, and `zg` to accept a word.

## Tests and terminals

Neotest uses `<leader>tr` for the nearest test, `<leader>tt` for the current
file, and `<leader>tl` for the last run. `<C-/>` toggles the primary terminal;
the `<leader>;` group contains split terminals, pytest, the Python REPL, and
Lazygit.
