"""Exercise real Neovim input and the Python and C language tools. Requires installed plugins/tools and pynvim.
Run from this checkout: python3 tests/editor_workflow.py
All edited files, environments, caches, and logs are temporary.
"""

import os
import tempfile
import time
import venv
from pathlib import Path

import pynvim


def main():
    config = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="nvim-workflow-") as directory:
        root = Path(directory)
        os.environ["XDG_CACHE_HOME"] = str(root / "cache")
        os.environ["XDG_STATE_HOME"] = str(root / "state")
        project = root / "project"
        project.mkdir()
        (project / "pyproject.toml").write_text(
            '[project]\nname = "workflow-test"\nversion = "0.0.0"\n'
            '[tool.ruff.lint]\nselect = ["E4", "E7", "E9", "F"]\n'
        )
        venv.EnvBuilder(with_pip=False).create(project / ".venv")
        site = next((project / ".venv/lib").glob("python*/site-packages"))
        (site / "workflow_probe.py").write_text(
            'def greet(name: str) -> str:\n    """Return a documented greeting."""\n    return name\n'
        )
        probe = project / "probe.py"
        probe.write_text(
            'import sys\nfrom workflow_probe import greet\nanswer: int = "wrong"\ngreet("hi")\n'
        )
        (project / "picked.py").write_text("picked = True\n")
        n = pynvim.attach(
            "child",
            argv=[
                "nvim",
                "--embed",
                "--headless",
                "-i",
                "NONE",
                "-n",
                "-u",
                str(config / "init.lua"),
            ],
        )
        n.ui_attach(140, 45, rgb=True)

        def lua(code, *args):
            return n.exec_lua(code, *args)

        def keys(text):
            n.input(text)
            time.sleep(0.08)
            assert n.api.get_mode()["mode"] not in {"r", "rm", "r?"}, (
                f"Unexpected prompt after {text!r}"
            )

        def wait(code, description, timeout=10):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if lua(code):
                    return
                time.sleep(0.05)
            raise AssertionError(f"{description}\n{n.command_output('messages')}")

        def lines():
            return n.current.buffer[:]

        def set_lines(content):
            keys("<Esc>")
            n.current.buffer[:] = content
            n.current.window.cursor = (len(content), 0)

        def check(label):
            print("PASS:", label, flush=True)

        try:
            # Scratch buffers should support editing without starting Ruff on an invalid URI.
            n.command("setfiletype python")
            cases = [
                ("values = [<CR>1,<CR>2,", ["values = [", "    1,", "    2,", "]"]),
                (
                    'data = {<CR>"key": [<CR>1,',
                    ["data = {", '    "key": [', "        1,", "    ]", "}"],
                ),
                ("call(<CR>value,", ["call(", "    value,", ")"]),
                ('"hello"', ['"hello"']),
                ('"""<CR>hello', ['"""', "hello", '"""']),
                ("'hello'", ["'hello'"]),
                ("(<BS>", [""]),
                ("if True:<CR>value = 1", ["if True:", "    value = 1"]),
            ]
            for typed, expected in cases:
                set_lines([""])
                keys("i" + typed)
                assert lines() == expected, (typed, lines())
            keys("<Esc>")
            assert lua("return #vim.lsp.get_clients({bufnr=0})") == 0
            check(
                "pairing, triple quotes, deletion, nested indentation, and scratch buffers"
            )

            n.command("write " + str(project / "fresh.py"))
            wait(
                "return #vim.lsp.get_clients({bufnr=0}) == 2",
                "First save did not start Python servers",
            )
            check("Python servers start after an unnamed buffer's first save")

            # Window mappings operate on the actual split layout.
            initial = n.current.window.handle
            keys(" |")
            right = n.current.window.handle
            assert initial != right and len(n.windows) == 2
            keys("<C-h>")
            assert n.current.window.handle == initial
            keys("<C-l>")
            assert n.current.window.handle == right
            keys(" -")
            assert len(n.windows) == 3
            keys(" wd")
            assert len(n.windows) == 2
            keys(" wo")
            assert len(n.windows) == 1
            check("split, focus, and close window shortcuts")

            n.command("edit! " + str(probe))
            wait(
                "return #vim.lsp.get_clients({bufnr=0}) == 2",
                "Python servers did not attach",
            )
            clients = lua(
                "return vim.tbl_map(function(c) return {name=c.name, python=c.settings.python, root=c.config.root_dir} end, vim.lsp.get_clients({bufnr=0}))"
            )
            bp = next(c for c in clients if c["name"] == "basedpyright")
            assert bp["python"]["pythonPath"] == str(project / ".venv/bin/python"), (
                clients
            )
            assert all(c["root"] == str(project) for c in clients)
            wait(
                'return vim.iter(vim.diagnostic.get(0)):any(function(d) return d.code == "reportAssignmentType" end)',
                "Missing type diagnostics",
            )
            diagnostics = lua("return vim.diagnostic.get(0)")
            assert any(d.get("code") == "F401" for d in diagnostics), diagnostics
            assert any(d.get("code") == "reportAssignmentType" for d in diagnostics), (
                diagnostics
            )
            assert not any(
                d.get("code") == "reportMissingImports" for d in diagnostics
            ), diagnostics
            assert not lua("return vim.lsp.inlay_hint.is_enabled({bufnr=0})")
            check(
                "both Python servers, project virtualenv imports, type/lint diagnostics, hints off"
            )
            n.current.window.cursor = (4, 1)
            keys("K")
            wait(
                'return vim.iter(vim.api.nvim_list_wins()):any(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end)',
                "Hover documentation missing",
            )
            float_text = lua(
                'local out = {}; for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= "" then vim.list_extend(out, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)) end end; return out'
            )
            assert any("documented greeting" in line for line in float_text), float_text
            lua(
                'for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= "" then vim.api.nvim_win_close(w, true) end end'
            )
            keys(" uh")
            assert lua("return vim.lsp.inlay_hint.is_enabled({bufnr=0})")
            keys(" uh")
            check("K opens Python LSP hover docs and inlay hints toggle explicitly")

            def completion(select_key="<C-n>"):
                set_lines(['text = "hello"', "text.up"])
                keys("Ap")
                wait(
                    'return require("blink.cmp").is_menu_visible()',
                    "Completion menu missing",
                )
                assert lua('return require("blink.cmp").get_selected_item()') is None
                assert lines()[-1] == "text.upp"
                if select_key is None:
                    return
                keys(select_key)
                item = lua('return require("blink.cmp").get_selected_item()')
                assert item["label"] in {"upper", "isupper"}, item
                assert lines()[-1] == "text.upp", (
                    "Selecting a completion changed the buffer"
                )
                return item["label"]

            completion()
            wait(
                'return require("blink.cmp").is_documentation_visible()',
                "Selected-item documentation missing",
            )
            assert lua('return require("blink.cmp").is_ghost_text_visible()')
            docs = lua(
                'return vim.api.nvim_buf_get_lines(require("blink.cmp.completion.windows.documentation").win:get_buf(), 0, -1, false)'
            )
            assert any("upper" in line.lower() for line in docs), docs
            check(
                "real Python completions, documentation, and non-mutating inline preview"
            )

            for key in ["<Tab>", "<Esc>", "<C-e>", "<Right>", ".", "("]:
                completion()
                keys(key)
                assert "upper" not in "\n".join(lines()), (key, lines())
            completion(select_key=None)
            keys("<CR>")
            assert lines() == ['text = "hello"', "text.upp", ""], lines()
            completion()
            keys("<C-e>")
            keys("<CR>")
            assert lines() == ['text = "hello"', "text.upp", ""], lines()
            for select_key in ["<C-n>", "<C-p>"]:
                selected = completion(select_key=select_key)
                keys("<CR>")
                assert lines() == ['text = "hello"', "text." + selected], lines()
            check(
                "Enter accepts only after explicit selection; unselected/dismissed menus preserve newlines"
            )
            check("Tab/Escape/arrows/punctuation never accept")

            keys("<Esc> uc")
            set_lines(['text = "hello"', "text.up"])
            keys("Ap")
            time.sleep(0.4)
            assert not lua('return require("blink.cmp").is_menu_visible()')
            keys("<C-Space>")
            wait(
                'return require("blink.cmp").is_menu_visible()',
                "Manual completion missing",
            )
            keys("<Esc> uc")
            check("manual-only completion toggle")

            # Confirm source actions remain explicit and formatting never applies lint fixes.
            set_lines(["import sys", "import os", "print(os.name,sys.version)"])
            n.command("write")
            assert lines()[:2] == ["import sys", "import os"], lines()
            assert lines()[-1] == "print(os.name, sys.version)", lines()
            keys(" co")
            wait(
                'return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "import os"',
                "Organize imports failed",
            )
            check("Ruff format-on-save and explicitly requested import organization")

            # MiniPick runs an input loop; dispatch it asynchronously through the mapping.
            keys("<Esc>")
            n.command("set nomodified")
            for key, axis in [("<C-v>", 1), ("<C-x>", 0)]:
                n.command("only")
                original = n.current.window
                keys("  ")
                keys("picked")
                wait(
                    "return MiniPick.is_picker_active() and #MiniPick.get_picker_matches().all == 1",
                    "Picker match missing",
                )
                keys(key)
                wait("return not MiniPick.is_picker_active()", "Picker did not close")
                assert n.current.buffer.name == str(project / "picked.py")
                assert len(n.windows) == 2
                assert (
                    n.api.win_get_position(n.current.window)[axis]
                    > n.api.win_get_position(original)[axis]
                )
            check("file picker opens chosen files right and below")

            # C: headers are C, clangd warns with -Wall, clang-format on save, build, run, man.
            c_dir = project / "c"
            c_dir.mkdir()
            hello = c_dir / "hello.c"
            hello.write_text(
                '#include <stdio.h>\nint main(void){int unused;printf("hi from c\\n");return 0;}\n'
            )
            (c_dir / "util.h").write_text("int add(int a, int b);\n")
            n.command("only")
            n.command("edit! " + str(c_dir / "util.h"))
            assert lua("return {vim.bo.filetype, vim.bo.shiftwidth}") == ["c", 4]
            n.command("edit! " + str(hello))
            wait(
                'return #vim.lsp.get_clients({bufnr=0, name="clangd"}) == 1',
                "clangd did not attach",
            )
            assert lua('return vim.fn.exists(":LspClangdSwitchSourceHeader")') == 2
            wait(
                'return vim.iter(vim.diagnostic.get(0)):any(function(d) return d.message:lower():find("unused") ~= nil end)',
                "Missing clangd -Wall warning",
                timeout=30,
            )
            check("header files are C; clangd attaches and reports -Wall warnings")
            n.command("write")
            assert lines()[1:3] == ["int main(void) {", "    int unused;"], lines()
            check("clang-format on save with the shared four-space style")
            keys(" mb")
            wait(
                f'return vim.fn.executable("{c_dir / "hello"}") == 1',
                "Build produced no program",
            )
            quickfix = lua("return vim.fn.getqflist()")
            assert any("unused" in item["text"] for item in quickfix), quickfix
            assert lua("return vim.bo.filetype") == "c", (
                "Focus did not return to the source"
            )
            check(
                "Space m b compiles the current file; gcc warnings fill the quickfix list"
            )
            keys(" mr")
            wait(
                'return vim.bo.buftype == "terminal" and vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(l) return l:find("hi from c", 1, true) ~= nil end)',
                "Program output missing",
            )
            keys("<Esc><Esc>")
            check("Space m r runs the program in a project terminal")
            n.command("edit! " + str(hello))
            n.current.window.cursor = (4, 4)
            keys(" mk")
            wait(
                'return vim.api.nvim_buf_get_name(0):find("man://printf", 1, true) ~= nil',
                "Manual page missing",
            )
            check("Space m k opens the manual page for the word under the cursor")

            # Valgrind runs a sanitizer-free copy; make runs through Bear for clangd.
            n.command("edit! " + str(hello))
            keys(" mv")
            wait(
                'return vim.bo.buftype == "terminal" and vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(l) return l:find("ERROR SUMMARY: 0 errors", 1, true) ~= nil end)',
                "Valgrind summary missing",
                timeout=30,
            )
            keys("<Esc><Esc>")
            assert (c_dir / "hello.valgrind").exists()
            check("Space m v builds without sanitizers and runs Valgrind")
            mk = project / "mk"
            mk.mkdir()
            (mk / "Makefile").write_text(
                "CFLAGS = -g -DGREETING=1\napp: main.c\n\t$(CC) $(CFLAGS) -o app main.c\n"
            )
            (mk / "main.c").write_text(
                '#ifdef GREETING\n#warning "GREETING set"\n#else\n#error "GREETING missing"\n#endif\n'
                "int main(void) {\n    return GREETING;\n}\n"
            )
            n.command("edit! " + str(mk / "main.c"))
            wait(
                'return vim.iter(vim.diagnostic.get(0)):any(function(d) return d.message:find("GREETING missing", 1, true) ~= nil end)',
                "Missing clangd error before the compile database exists",
                timeout=30,
            )
            keys(" mb")
            wait(
                f'return vim.fn.executable("{mk / "app"}") == 1',
                "make did not build the program",
            )
            assert "-DGREETING=1" in (mk / "compile_commands.json").read_text()
            wait(
                'return vim.iter(vim.diagnostic.get(0)):any(function(d) return d.message:find("GREETING set", 1, true) ~= nil end)',
                "clangd did not pick up the compile database",
                timeout=30,
            )
            check(
                "Space m b runs make through Bear and clangd adopts the recorded flags"
            )
            assert not lua("return vim.v.errmsg"), n.command_output("messages")
        finally:
            n.input("<C-c><Esc>")
            try:
                n.command("qa!")
            except EOFError:
                pass


if __name__ == "__main__":
    main()
