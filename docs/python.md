# Python workflow

Press Space, then p or d, and pause to discover the Python or debugger actions.
Space ? opens the main configuration guide; Space p h opens this page.

## Environments

Tests, scripts, and REPLs run the current project's `.venv/bin/python`, with
the project root as their working directory. Test history and REPL state are
separate for each project. Prepare environments using the project's documented
uv command. These shortcuts do not synchronize or change project dependencies.

Ruff and Pyright prefer the executable in the project's `.venv/bin`, using
Mason's standalone tools when the project lacks those executables. Each tool
reads the project's own configuration. Debugpy is installed separately by
Mason, and launches your code with the project's Python interpreter.

## Editing

Saving a Python file formats it with Ruff. This changes layout, quoting, and
spacing according to that project's settings. It does not organize imports or
apply lint fixes. Pyright supplies completion, types, definition lookup, and
documentation; Ruff adds lint diagnostics and code actions.

| Keys | Action |
| --- | --- |
| Space c f | Format now |
| Space c F | Toggle formatting on save for this buffer |
| Space c i | Organize imports explicitly |
| Space c x | Apply Ruff's available lint fixes explicitly |
| `gra` | Choose a code action at the cursor |
| `[d` / `]d` | Previous / next diagnostic |
| Space c d | Read the diagnostic |
| `gd`, then Ctrl+o | Follow a definition, then return |
| `K` | Read documentation |
| `grn` | Rename a symbol |

Ruff's default fix policy applies safe fixes; neither this configuration nor
the save hook enables unsafe fixes. For a deliberate exception to formatting,
use Space c F. The toggle resets when the buffer is recreated.
`:ConformInfo` shows the selected formatter and its log. `:checkhealth vim.lsp`
shows attached language servers. A formatter failure is reported; it does not
prevent saving the file.

## Tests and scripts

| Keys | Action |
| --- | --- |
| Space p n | Run the nearest test in a pytest file |
| Space p f | Run the current pytest file |
| Space p a | Run the project's pytest suite |
| Space p l | Repeat this project's last run |
| Space p r | Run the current Python script |

vim-test finds the pytest function/class at the cursor. Above the first test,
the nearest-test action runs the file. A parameterized test runs its parameter
cases. Results appear in a terminal below, with pytest's output and exit code.
Repeat runs reuse the visible result window for that project, while older
output remains in its buffer. The test terminal opens in Normal mode for scrolling and searching; use `i`
to send input, including Ctrl+c to interrupt. Space , finds older result buffers.

These shortcuts save the current Python buffer before execution, which also
runs its formatter. Save other modified files yourself before relying on test
results. Reruns remember the selected target and project for this Neovim
session; they use the current contents of files on disk.

Tests run as `PROJECT/.venv/bin/python -m pytest ...` and honor the project's
pytest settings. For custom options or a particular parameter case, use the
project shell and your usual `uv run --no-sync pytest ...` command.
Space p r runs a file as a script; package modules can instead be run with
`uv run --no-sync python -m package.module` in a project terminal.

## Debugging

| Keys | Action |
| --- | --- |
| Space d b | Toggle a breakpoint on this line |
| Space d B | Set a conditional breakpoint |
| Space d c | Start a launch configuration / continue a paused program |
| Space d n | Debug the nearest pytest test |
| Space d f | Debug the current pytest file |
| Space d o | Step over the current statement |
| Space d i | Step into a function call |
| Space d O | Step out of the current function |
| Space d e | Inspect the value under the cursor |
| Space d s | Show/hide the variables sidebar |
| Space d r | Show/hide the debugger console |
| Space d q | Terminate the debug session |

To start, open a Python file and use Space d c. The picker offers the current
file, the current file with arguments, or a module such as `package.module`.
Arguments accept shell-style quoting. The program's input/output uses a
terminal below. A `B` marks a breakpoint; `>` marks the paused line.

In a pytest file, Space d n launches that test directly. Set a breakpoint in
the test or the code it calls first. At the breakpoint, step over to advance
one statement, step into to follow a call, and step out to finish that function.
Open variables with Space d s and press Enter on a value to expand it. The
debugger console evaluates Python expressions in the paused stack frame.

The debugger starts with `justMyCode = true`: normal stepping focuses on your
code. It is independent of the project REPL below. Use `:help dap` for more
advanced configuration and adapter behavior.

## Interactive exploration

Space p i opens or returns to a persistent Python interpreter for this project.
Use it like a normal Python REPL, including `help()` and `dir()`. Press Escape
twice to return to Terminal-Normal mode and use native Ctrl+w window commands
to return to your file.

In a Python file, Space p s sends the current line. In Visual mode it sends
the selection, removes common indentation, and displays a final expression's
value. This works with multiline statements. For example, select:

```python
values = [1, 2, 3]
[value * 2 for value in values]
```

Press Space p s to see `[2, 4, 6]`. Variables and imports persist for subsequent
selections. Sending code keeps focus in the editor and opens the REPL below
if it was hidden. This uses the current text, including unsaved changes.

Select a logical unit of code: `vip` selects a paragraph, and `V` followed by
motions selects complete lines. A selection containing `return`, `break`, or
`continue` needs its enclosing function/loop to be valid Python.

Type `exit()` or press Ctrl+d at an empty prompt to stop the REPL. The next
Space p i starts fresh. An import stays cached in a running interpreter;
restart it when you need a clean experiment. Python tracebacks identify the
source file, with line numbers relative to the submitted selection.

The small `scripts/repl.py` helper accepts temporary files containing selected
code, deletes them after reading, and evaluates the code in the persistent
interpreter. `_nvim_exec` is reserved for this connection.

## A first practice loop

1. Open an existing test with Space Space. Read its assertions and follow a
   called function with gd; return with Ctrl+o.
2. Save an edit, then run that test with Space p n. Make another edit and
   repeat with Space p l.
3. Set a breakpoint with Space d b, debug the test with Space d n, inspect a
   variable with Space d e, and advance with Space d o. End with Space d q.
4. Try a small data transformation in the project REPL by selecting a paragraph
   with vip and sending it with Space p s.

Work through one loop until it feels familiar before trying every command.
