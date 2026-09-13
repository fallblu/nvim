"""A project Python REPL that can also receive selected Neovim code."""

import ast
import code
import sys
import textwrap
from pathlib import Path


def main():
    namespace = {"__name__": "__main__"}

    def execute(path, filename):
        source_file = Path(path)
        try:
            source = textwrap.dedent(source_file.read_text(encoding="utf-8"))
        finally:
            source_file.unlink(missing_ok=True)
        namespace["__file__"] = filename
        tree = ast.parse(source, filename=filename)
        # Match normal REPL behavior: show the value of a final expression.
        expression = (
            tree.body.pop()
            if tree.body and isinstance(tree.body[-1], ast.Expr)
            else None
        )
        exec(compile(tree, filename, "exec"), namespace)  # noqa: S102 - this is a REPL
        if expression is not None:
            value = eval(
                compile(ast.Expression(expression.value), filename, "eval"), namespace
            )
            sys.displayhook(value)

    namespace["_nvim_exec"] = execute
    sys.path.insert(0, str(Path.cwd()))
    code.interact(
        banner="Project Python — send code with Space p s", local=namespace, exitmsg=""
    )


if __name__ == "__main__":
    main()
