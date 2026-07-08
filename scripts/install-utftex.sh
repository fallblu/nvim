#!/usr/bin/env bash
# Builds and installs `utftex` (from bartp5/libtexprintf) as a static binary
# at ~/.local/bin/utftex, so render-markdown.nvim can render LaTeX math in
# markdown buffers as real Unicode (superscripts, stacked fractions, etc).
# Re-run any time to rebuild/reinstall (e.g. after a fresh machine setup).
#
# One-time prerequisite (needs a real terminal for the sudo password prompt):
#   sudo apt install -y autoconf automake libtool build-essential
set -euo pipefail

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

git clone --depth 1 --branch v1.31 https://github.com/bartp5/libtexprintf.git "$WORKDIR/libtexprintf"
cd "$WORKDIR/libtexprintf"

./autogen.sh
./configure --prefix="$HOME/.local" --disable-shared --enable-static
make -j"$(nproc)"
make install

echo "Installed: $HOME/.local/bin/utftex"
"$HOME/.local/bin/utftex" --version
