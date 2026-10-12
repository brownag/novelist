#!/bin/sh
set -eu

if [ -n "${NVIM:-}" ]; then
  nvim_bin=$NVIM
else
  nvim_bin=$(command -v nvim || true)
fi

if [ -z "$nvim_bin" ] || ! command -v "$nvim_bin" >/dev/null 2>&1; then
  printf '%s\n' 'error: Neovim executable not found (set NVIM to its path)' >&2
  exit 127
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
exec "$nvim_bin" --headless -u NONE \
  --cmd 'lua vim.opt.rtp:prepend(vim.fn.getcwd())' \
  -c "lua dofile(vim.fn.getcwd() .. '/tests/run.lua')"
