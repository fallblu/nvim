# C++ workflow

Press Space, then m or d, and pause to discover the C++ or debugger actions.
Space ? opens the main configuration guide; Space m h opens this page.

## Tools

Ubuntu packages supply g++ 15, GNU make, gdb, and the C library manual
pages, plus Bear and Valgrind; the optional `libstdc++-15-doc` package adds
manual pages for the C++ standard library. Mason supplies the tools Neovim
talks to: clangd (language server), clang-format, and codelldb (debug
adapter); `:Mason` lists them. Make runs through Bear, which records each
compile command in `compile_commands.json` so clangd checks a project with its
real flags, and Space m v runs a program under Valgrind's memory checker.

## Editing

clangd attaches to named C++ files: `.cpp`, `.cc`, `.cxx`, `.hpp`, and `.h`,
since header files count as C++ here. Without a compile database it checks
files with the same flags the build uses, plus clang-tidy's default checks,
so warnings appear while typing and again when building. These are learncpp's
recommended warnings: `-Wconversion` and `-Wsign-conversion` catch values
that change on conversion, such as `int i = 3.7;` or `unsigned u = -1;`,
`-Wshadow` catches an inner name hiding an outer one, and `-pedantic-errors`
rejects compiler extensions, such as variable-length arrays, that are not
standard C++. A project can add a `.clangd` file or
`compile_commands.json` to change that.

Completion offers functions, classes, members, and variables from the included
headers, with signatures in the documentation window. Accepting a function
inserts its name only: type `(` to start the call, then Ctrl+g, s shows the
parameters, including each overload. Accepting a standard library name whose
header is missing, such as `std::vector`, adds the `#include`.

| Keys | Action |
| --- | --- |
| K | Declaration, type, and any comment for the name under the cursor |
| gd / grr | Definition / references, including across headers |
| gri | Implementations, such as the overrides of a virtual function |
| Space c r / Space c a | Rename / code actions, such as clangd's suggested fixes |
| Space c h | Switch between a source file and its header |
| Space c d / Space c D | Read the diagnostic at the cursor / list diagnostics |
| Space u h | Toggle inlay hints showing deduced `auto` types and parameter names |
| Space c f / Space c F | Format now / toggle format on save for this buffer |
| Space m k | Manual page for the word under the cursor |
| gcc / gc + motion | Comment or uncomment a line / the lines of a motion |

K is the quickest way to learn what an expression is: on a variable declared
with `auto` it shows the deduced type, and on a standard library name it
shows the declaration from the header.

Saving formats the file with clang-format. A `.clang-format` file in the
project or a parent directory decides the style; without one, the shared
`styles/clang-format.yaml` applies: LLVM style with four-space indents and
`public:` / `private:` level with their class. While typing, blocks indent by
four spaces, `case` labels sit level with their `switch`, namespace contents
are not indented, and Enter between `{` and `}` opens an indented block. `==`
reindents a line and `=` reindents a Visual selection.

## Build and run

| Keys | Action |
| --- | --- |
| Space m b | Save and build: make, or g++ for this file alone |
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
g++ -std=c++23 -Wall -Wextra -Wconversion -Wsign-conversion -Wshadow -pedantic-errors \
    -g -O0 -fsanitize=address,undefined -o hello hello.cpp
```

The program lands beside its source, `hello` next to `hello.cpp`. Warnings and
errors fill the quickfix list, which opens below whenever there are any; the
cursor stays in your file. Press Enter on an entry to jump to it, or use `]q`
and `[q`. A failure that produces no located diagnostic, such as a missing
make target, is shown as a message instead.

Template errors are long. The first `error:` entry is usually the one to read;
the `required from` entries after it trace which line of your code asked for
the template, and the last of them is typically in your file.

Make runs through Bear, which records every compile command in
`compile_commands.json` beside the Makefile. clangd then checks those files
with the project's real flags rather than the fallback ones, and it restarts
for that project whenever a build changes the recorded commands. The file is
generated, so keep it out of version control.

Space m r runs the program in a terminal below, in Insert mode so you can
type input for `std::cin`. Press Esc twice for Terminal-Normal mode, Ctrl+k
to return to your file, and `i` in the terminal to type again. Each run reuses
the visible result window and stops a program still running there; earlier
output remains available through Space ,. The program runs in the project
root (the nearest Makefile's directory, else the Git root, else the file's own
directory), so relative file paths such as `std::ifstream{"input.txt"}` are
read from there.

For a single-file build, the program is known. For make, Space m r runs the
program named after the current file, `loops` for `loops.cpp`, when make built
one; otherwise it runs the program you chose with Space m p, asking once per
project. Choose again with Space m p when a Makefile builds something else,
such as `build/calc`.

The sanitizer flags make the program check itself as it runs. Writing past
the end of an array, using an object after `delete`, releasing `new[]` memory
with plain `delete`, or overflowing a signed integer stops the program with a
report such as:

```
==4242==ERROR: AddressSanitizer: stack-buffer-overflow on address 0x7ffd...
WRITE of size 4 at 0x7ffd... thread T0
    #0 0x55d4... in main /home/garrett/learn-cpp/hello.cpp:7
```

The first `#0` line in your file names the line; frames above it may be inside
the standard library. Undefined-behavior reports are shorter:
`hello.cpp:9:15: runtime error: signed integer overflow`. These checks make the
program slower; for a fast build, compile in a project terminal with
`g++ -std=c++23 -O2 -o hello hello.cpp` or give a Makefile its own `CXXFLAGS`.

Standard containers check themselves too: Ubuntu's g++ enables libstdc++'s
assertions, so an out-of-range `std::vector` or `std::string` index stops the
program with `Assertion '__n < this->size()' failed` and the header line
rather than a sanitizer report. Run it under the debugger (Space d c) and `bt`
in the console shows which of your lines made the call.

### Valgrind

Space m v builds a copy of the program without sanitizers, `hello.valgrind`
beside `hello`, and runs it under Valgrind's memory checker in the terminal
below; Space m V asks for arguments first. The sanitizers and Valgrind cannot
share a program, so a Makefile project is rebuilt with `make -B SANITIZE=0`,
copied, and then rebuilt normally again. Give your Makefiles these lines so
they understand `SANITIZE`:

```make
SANITIZE ?= 1
ifeq ($(SANITIZE),1)
CXXFLAGS += -fsanitize=address,undefined
endif
```

Valgrind is slower than the sanitizers but reports mistakes they miss, above
all reading memory that was never written:

```
==4242== Conditional jump or move depends on uninitialised value(s)
==4242==    at 0x...: main (hello.cpp:6)
==4242==  Uninitialised value was created by a heap allocation
==4242==    at 0x...: operator new[](unsigned long) (vg_replace_malloc.c:...)
==4242==    by 0x...: main (hello.cpp:5)
```

Each report ends with the line in your file. `ERROR SUMMARY: 0 errors` and
`All heap blocks were freed` mean a clean run. The sanitizers remain the everyday check: they are faster and
also catch stack overruns, which Valgrind does not see.

A program spanning several files gets its own directory and Makefile; built
alone, `main.cpp` would fail to link with `undefined reference` to the
functions defined in its other files. `templates/cpp/Makefile` links every
`.cpp` in its directory into `main`, rebuilding what changed, including the
sources that include an edited header. Copy it into the program's directory:

```sh
mkdir -p ch02/2.8-multiple-files && cp ~/.config/nvim/templates/cpp/Makefile ch02/2.8-multiple-files/
```

Keep it out of the top of a repository of single-file exercises: the nearest
Makefile above a file decides how that file builds. Recipe lines start with a
Tab, which Neovim keeps in Makefiles. Space m b runs `make` there, and Space m
r from `main.cpp` runs `main`; from another file it asks once which program to
run, so choose `main` with Space m p.

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

Space d c in a C++ file builds exactly as Space m b does, then offers the
program with or without arguments. It runs under codelldb in a terminal below,
so it can read input. `B` marks a breakpoint and `>` the paused line. Space d e
shows a variable's value; Space d s lists locals, and Enter expands objects,
arrays, and pointers. Standard library containers such as `std::vector` and
`std::string` show their elements and text. In the console, start an
expression with `?`, as in `?total * 2` or `?values.size()`; other input is
an LLDB command such as `bt` for the call stack or `frame variable` for all
locals. Space d i on a line that calls into the standard library steps into
its headers; Space d O returns to your code. After the program ends, the
terminal shows two extra lines mentioning EOF and exit code 1; they come from
the debugger's terminal helper shutting down, not from your program.

A sanitizer report under the debugger stops the program at the faulty line,
so `bt` and the variables sidebar show how it got there. Leak detection is off
during debugging because it cannot run under a debugger.

To learn gdb itself, run it in a project terminal (Space t t):
`gdb ./hello`, then `break main`, `run`, `next`, `step`, `print total`, `bt`,
and `quit`. `gdb --tui ./hello` adds a source view.

## Manual pages

Space m k on a standard library name, such as `vector` in `std::vector` or in
`#include <vector>`, opens its std::vector(3cxx) page when `libstdc++-15-doc`
is installed. Otherwise it tries C library functions (section 3), such as
`printf` or `strlen`, then system calls (section 2), then any section.
`:Man 3cxx std::map` or `:Man 2 open` name a page directly. Inside a page, `q`
closes it, `K` on a referenced name opens that page, `gO` lists the page's
sections, and Ctrl+o returns. For the fullest reference, K on a name shows
clangd's summary and https://en.cppreference.com covers the whole language.

## Starting a project

Create a directory with Git and a first file, then start a session:

```sh
mkdir ~/learn-cpp && cd ~/learn-cpp && git init
~/.config/nvim/scripts/work ~/learn-cpp
```

In Neovim, `:edit hello.cpp` and write:

```cpp
#include <iostream>

int main() {
    std::cout << "Hello, C++\n";
    return 0;
}
```

A single file needs no Makefile: Space m r builds and runs it. New exercises
can live in folders: `:edit ch1/loops.cpp` then `:write ++p` creates the
folder on the first save. Built programs have no extension, so copy
`templates/cpp/gitignore` to `.gitignore`: it ignores everything except
sources, headers, Makefiles, and notes.

## A first practice loop

1. Open `hello.cpp` with Space Space and run it with Space m r. Press Esc twice
   and Ctrl+k to return to the file.
2. Remove a semicolon and press Space m b. Use `]q` to reach the error, fix
   it, and run again. Then write `unsigned int count = -1;`: the sign
   conversion is flagged while you type and again in the build list.
3. Declare `int values[3];` and assign `values[3] = 1;`. Run the program and
   read the AddressSanitizer report down to the `#0` line naming your file.
   Then try `std::vector<int> items(3);` and `items[3] = 1;`: Ubuntu's g++
   checks container indexes itself, so the program stops with
   `Assertion '__n < this->size()' failed` instead.
4. Print an element of `new int[3]` without assigning it first. The sanitized
   run prints a meaningless number; Space m v reports the uninitialised value.
   Release it with `delete` instead of `delete[]` and the sanitized run stops
   with `alloc-dealloc-mismatch`.
5. Write `auto total = items.size();`, put the cursor on `total`, and press K
   to see the deduced type.
6. Set a breakpoint inside a loop with Space d b, start with Space d c, inspect
   a variable with Space d e, step with Space d o, and end with Space d q.

Work through one loop until it feels familiar before trying every command.
