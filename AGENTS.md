# AGENTS.md — novelist

## Quick Start

- `make` — list available targets.
- `make test` — run the dependency-free headless test suite (`./tests/run.sh`).
- `make docs-check` — generate help tags and verify `:help novelist` resolves (requires Neovim).
- `make clean` — remove generated `doc/tags`.
- Release validation also requires the manual Neovim 0.12+ smoke test documented in `README.md`.

## Find Things

- `lua/novelist/` — plugin implementation: setup, prose settings, commands, and revision cockpit.
- `plugin/novelist.lua` — runtime plugin entry point; initializes defaults.
- `tests/` — headless test runner, helpers, and unit/integration tests.
- `doc/novelist.txt` — Neovim help documentation.
- `README.md` — user installation, configuration, commands, and smoke-test instructions.
- `docs/decisions/` — architecture decision records; `docs/research/` — project research.
- `planning/` — execution plans, task prompts/state, and task records.
- `skills/neovim-plugins/` — project-specific Neovim plugin guidance.
- `TODO.md` — maintained work list; `reports/` and `research_notes/` — supporting research artifacts.

## Workflows

- Add or update automated coverage under `tests/`; run `make test`.
- Keep user-facing behavior and configuration documented in `README.md` and `doc/novelist.txt`.
- For release checks, verify help with `make docs-check`, remove generated tags with `make clean` if they are not intended for commit, and perform the documented Neovim 0.12+ manual smoke test.
- Track planned work in `TODO.md` and use the planning artifacts under `planning/` as applicable.

## Infrastructure

- This is a dependency-free Lua Neovim plugin; there is no separate build or install step.
- Runtime module namespace: `novelist` (`require('novelist')`).
- Neovim release target: 0.12+.
- Test runner: `tests/run.sh`; Makefile targets are the canonical command interface.

## References

- `README.md` — user-facing usage and configuration.
- `doc/novelist.txt` — Neovim help.
- `docs/decisions/README.md` — architecture decision record index.
- `skills/neovim-plugins/SKILL.md` — plugin development guidance.
