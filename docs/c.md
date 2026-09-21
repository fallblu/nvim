# C workflow

Press Space, then m or d, and pause to discover the C or debugger actions.
Space ? opens the main configuration guide; Space m h opens this page.

## Tools

Ubuntu packages supply gcc 15, GNU make, gdb, and the C library manual
pages, plus Bear and Valgrind. Mason supplies the tools Neovim talks to:
clangd (language server), clang-format, and codelldb (debug adapter); `:Mason`
lists them. Make runs through Bear, which records each compile command in
`compile_commands.json` so clangd checks a project with its real flags, and
Space m v runs a program under Valgrind's memory checker.

## Editing

clangd attaches to named `.c` and `.h` files; header files count as C here,
not C++. Without a compile database it checks files with the same
`-std=c17 -Wall -Wextra -Wpedantic` flags the build uses, plus clang-tidy's
default checks, so warnings appear while typing and again when building.
A project can add a `.clangd` file or `compile_commands.json` to change that.

Completion offers functions, types, and variables from the included headers,
with signatures in the documentation window. Accepting a function inserts its
name only: type `(` to start the call, then Ctrl+g, s shows the parameters.
Accepting a library function whose header is missing adds the `#include`.

| Keys | Action |
| --- | --- |
| K | Declaration and any comment for the name under the cursor |
| gd / grr | Definition / references, including across headers |
| Space c r / Space c a | Rename / code actions, such as clangd's suggested fixes |
| Space c h | Switch between a source file and its header |
| Space c d / Space c D | Read the diagnostic at the cursor / list diagnostics |
| Space u h | Toggle inlay hints showing parameter names in calls |
| Space c f / Space c F | Format now / toggle format on save for this buffer |
| Space m k | Manual page for the word under the cursor |
| gcc / gc + motion | Comment or uncomment a line / the lines of a motion |

Saving formats the file with clang-format. A `.clang-format` file in the
project or a parent directory decides the style; without one, the shared
`styles/clang-format.yaml` applies: LLVM style with four-space indents. While
typing, blocks indent by four spaces, `case` labels sit level with their
`switch`, and Enter between `{` and `}` opens an indented block. `==`
reindents a line and `=` reindents a Visual selection.

## Build and run

| Keys | Action |
| --- | --- |
| Space m b | Save and build: make, or gcc for this file alone |
| Space m r | Build, then run the program in a terminal below |
| Space m R | Build, then run the program with arguments |
| Space m v / Space m V | Build without sanitizers, then run under Valgrind, without / with arguments |
| Space m p | Choose the program to run or debug for this project |
| Space m m | Run a make target, such as `clean` |
| Space m q | Show / hide the build diagnostics list |
| `]q` / `[q` | Next / previous build diagnostic |

With a Makefile in the file's directory or above it, Space m b runs `make`
in the nearest Makefile's directory. Otherwise it compiles the file by itself:

```sh
gcc -std=c17 -Wall -Wextra -Wpedantic -g -O0 -fsanitize=address,undefined -o hello hello.c
```

The program lands beside its source, `hello` next to `hello.c`. Warnings and
errors fill the quickfix list, which opens below whenever there are any; the
cursor stays in your file. Press Enter on an entry to jump to it, or use `]q`
and `[q`. A failure that produces no located diagnostic, such as a missing
make target, is shown as a message instead.

Make runs through Bear, which records every compile command in
`compile_commands.json` beside the Makefile. clangd then checks those files
with the project's real flags rather than the fallback ones, and it restarts
for that project whenever a build changes the recorded commands. The file is
generated, so keep it out of version control; the starter's `.gitignore`
already does.

Space m r runs the program in a terminal below, in Insert mode so you can
type input for `scanf` and friends. Press Esc twice for Terminal-Normal mode,
Ctrl+k to return to your file, and `i` in the terminal to type again. Each
run reuses the visible result window and stops a program still running there;
earlier output remains available through Space ,.

For a single-file build, the program is known. For make, Space m r runs the
program named after the current file, `loops` for `loops.c`, when make built
one; otherwise it runs the program you chose with Space m p, asking once per
project. Choose again with Space m p when a Makefile builds something else,
such as `build/calc`.

The sanitizer flags make the program check itself as it runs. Writing past
the end of an array, using freed memory, or overflowing a signed integer stops
the program with a report such as:

```
==4242==ERROR: AddressSanitizer: stack-buffer-overflow on address 0x7ffd...
WRITE of size 4 at 0x7ffd... thread T0
    #0 0x55d4... in main /home/garrett/learn-c/hello.c:7
```

The first `#0` line names your file and line. Undefined-behavior reports are
shorter: `hello.c:9:15: runtime error: signed integer overflow`. These checks
make the program slower; for a fast build, compile in a project terminal with
`gcc -O2 -o hello hello.c` or give a Makefile its own `CFLAGS`.

### Valgrind

Space m v builds a copy of the program without sanitizers, `hello.valgrind`
beside `hello`, and runs it under Valgrind's memory checker in the terminal
below; Space m V asks for arguments first. The sanitizers and Valgrind cannot
share a program, so a Makefile project is rebuilt with `make -B SANITIZE=0`,
copied, and then rebuilt normally again. The starter Makefile understands
`SANITIZE`; give your own Makefiles the same lines:

```make
SANITIZE ?= 1
ifeq ($(SANITIZE),1)
CFLAGS += -fsanitize=address,undefined
endif
```

Valgrind is slower than the sanitizers but reports mistakes they miss, above
all reading memory that was never written:

```
==4242== Conditional jump or move depends on uninitialised value(s)
==4242==    at 0x...: main (hello.c:6)
==4242==  Uninitialised value was created by a heap allocation
==4242==    at 0x...: malloc (vg_replace_malloc.c:...)
==4242==    by 0x...: main (hello.c:5)
```

Each report ends with the line in your file. `ERROR SUMMARY: 0 errors` and
`All heap blocks were freed` mean a clean run. The sanitizers remain the
everyday check: they are faster and also catch stack overruns, which Valgrind
does not see.

A program spanning several files gets its own directory and Makefile. This one
builds `calc` from two sources, rebuilding what changed:

```make
CC = gcc
CFLAGS = -std=c17 -Wall -Wextra -Wpedantic -g -O0
SANITIZE ?= 1
ifeq ($(SANITIZE),1)
CFLAGS += -fsanitize=address,undefined
endif
objects = main.o list.o

calc: $(objects)
	$(CC) $(CFLAGS) -o $@ $(objects)

main.o: main.c list.h
list.o: list.c list.h

clean:
	rm -f calc calc.valgrind $(objects)

.PHONY: clean
```

Recipe lines start with a Tab, which Neovim keeps in Makefiles. Space m b runs
`make` there, and Space m r asks once which program to run.

## Debugging

| Keys | Action |
| --- | --- |
| Space d b / Space d B | Toggle a breakpoint / set a conditional breakpoint |
| Space d c | Build, then start the debugger; continue a paused program |
| Space d o / Space d i / Space d O | Step over / into / out |
| Space d e | Inspect the value under the cursor |
| Space d s | Show / hide the variables sidebar |
| Space d r | Show / hide the debugger console |
| Space d q | Terminate the debug session |

Space d c in a C file builds exactly as Space m b does, then offers the
program with or without arguments. It runs under codelldb in a terminal below,
so it can read input. `B` marks a breakpoint and `>` the paused line. Space d e
shows a variable's value; Space d s lists locals, and Enter expands arrays,
structs, and pointers. In the console, start an expression with `?`, as in
`?total * 2` or `?list->next->value`; other input is an LLDB command such as
`bt` for the call stack or `frame variable` for all locals. After the program
ends, the terminal shows two extra lines mentioning EOF and exit code 1; they
come from the debugger's terminal helper shutting down, not from your program.

A sanitizer report under the debugger stops the program at the faulty line,
so `bt` and the variables sidebar show how it got there. Leak detection is off
during debugging because it cannot run under a debugger.

To learn gdb itself, run it in a project terminal (Space t t):
`gdb ./hello`, then `break main`, `run`, `next`, `step`, `print total`, `bt`,
and `quit`. `gdb --tui ./hello` adds a source view.

## Manual pages

Space m k on `printf` opens printf(3) in a split. It tries section 3
(library functions), then section 2 (system calls), then any section. The
same works on header names such as `stdio` in an include line. `:Man 3 strtok`
or `:Man 2 open` name a page directly, and `:Man str` followed by Tab
completes. Inside a page, `q` closes it, `K` on a referenced name opens that
page, `gO` lists the page's sections, and Ctrl+o returns.

## Starter project

`~/learn-c` is a Git repository with nothing committed yet. It holds:

| File | Purpose |
| --- | --- |
| `hello.c` | A first program to run and change |
| `Makefile` | Builds every `.c` file in the tree into a program of the same name; `SANITIZE=0` leaves the sanitizers out |
| `.clang-format` | The project's formatting style, the same as the shared one |
| `.gitignore` | Keeps built programs out of version control |

The Makefile treats a subfolder that has its own Makefile as a separate
project and leaves it alone. Start a session and open the file:

```sh
~/.config/nvim/scripts/work ~/learn-c
```

New exercises can live in folders: `:edit ch1/loops.c` then `:write ++p`
creates the folder on the first save.

## A first practice loop

1. Open `hello.c` with Space Space and run it with Space m r. Press Esc twice
   and Ctrl+k to return to the file.
2. Remove a semicolon and press Space m b. Use `]q` to reach the error, fix
   it, and run again.
3. Declare `int values[3];` and assign `values[3] = 1;`. Run the program and
   read the AddressSanitizer report down to the `#0` line naming your line.
4. Print an `int` from `malloc` without assigning it first. The sanitized run
   prints a meaningless number; Space m v reports the uninitialised value.
5. Set a breakpoint inside a loop with Space d b, start with Space d c, inspect
   a variable with Space d e, step with Space d o, and end with Space d q.
6. Put the cursor on `printf` and press Space m k. Scroll, then press `q`.

Work through one loop until it feels familiar before trying every command.
