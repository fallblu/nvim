# Neovim workflow

This is a focused LazyVim configuration for Python, OCaml, Agda, pytest, and
embedded terminals. Navigation is picker-first, and Hardtime applies training
constraints that favor direct motions and operator-first edits.

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

## OCaml

OCaml tools are resolved through OPAM rather than Mason. The active global
switch is used by default. If an `_opam` directory is found above the current
project, that project-local switch is selected automatically. Install the
editor and workflow tools in every switch used for development:

```sh
opam install dune ocaml-lsp-server ocamlformat odoc utop
```

OCaml LSP supplies completion, navigation, diagnostics, code actions, semantic
highlighting, and signature help. `<localleader>i` switches between a `.ml`
implementation and its `.mli` interface. OCamlFormat runs on save for OCaml,
interface, OCamllex, and Menhir files; `dune format-dune-file` formats Dune
files. Project `.ocamlformat` files are honored, while standalone learning files
can still be formatted.

Run `<localleader>w` early in a project to start `dune build --watch`. The
persistent terminal can be hidden and reopened with the same key, and its Dune
RPC session gives ocamllsp fresher build information. The OCaml actions use
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
persistent and separate for each project.

The same actions are available as commands: `:OcamlActions`, `:OcamlBuild`,
`:OcamlWatch`, `:OcamlTest`, `:OcamlExec`, `:OcamlDocs`, `:OcamlUtop`,
`:OcamlSendPhrase`, `:OcamlSendLine`, `:OcamlSendFile`, and
`:OcamlSwitchImplIntf`. `:OcamlBuild`, `:OcamlTest`, and `:OcamlExec` accept
optional arguments; invoking `:OcamlExec` without arguments opens a prompt.

## Agda

Completion is explicit: `<Enter>` always inserts a newline and `<C-y>` accepts
the selected completion. In an Agda buffer, `<C-Space>` opens a searchable
Unicode reference in both Normal and Insert mode. Entries show their complete
input sequence, so `∷`, for example, is `\::<Tab>`. Choosing an entry inserts
it and leaves the buffer in Insert mode. `:AgdaUnicode` opens the same picker.

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

Files continue to load and type-check automatically after each save.
