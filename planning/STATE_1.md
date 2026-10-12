# State — Orchestration 1

Resume from this file and `planning/EXECUTION_PLAN_1.md`.

## Baseline checklist (before Wave 1)

- [x] Git repository initialized; branch `master`; initial commit `1fd0f27` (`Initial research`).
- [x] Confirmed repository contains only `docs/research/neovim-prose-narrative-plugins.md` before planning artifacts; no existing code/tests/docs convention.
- [x] Confirmed runtime: `/usr/bin/nvim`, version 0.11.6. Target is 0.12+; final target-version smoke validation is outstanding.
- [x] New headless harness empty-suite baseline: `./tests/run.sh` on Neovim 0.11.6 — 0 passed, 0 failed (exit 0).
- [x] Baseline established before Wave 2: `./tests/run.sh` passes with 0 tests discovered (0 passed, 0 failed). Neovim 0.12+ validation remains outstanding.

## Wave board

| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 1.1 Project foundation and headless test harness | done | Verified and committed on `master` |
| 2 | 2.1 Prose settings module | done | Verified by task worker; pending orchestration review/commit |
| 2 | 2.2 Heading, count, and marker parsing module | pending | Depends on 1.1 |
| 3 | 3.1 Public setup, settings lifecycle, and commands | pending | Depends on 2.1 and 2.2 |
| 4 | 4.1 User documentation and release-facing validation | pending | Depends on 3.1 |

Maximum concurrent workers: 2. Execute tasks in a wave in parallel only when their file scopes remain disjoint. Full/wave-level verification and commits are orchestrator-owned.

## Task reports

### 1.1 — Project foundation and headless test harness
- Status: done; verified and committed on `master` (`test: add dependency-free headless harness`).
- Files: `tests/helpers.lua` (1–68), `tests/run.lua` (1–6), `tests/run.sh` (1–19; executable), `planning/tasks/1.1.todo.md` (checked steps).
- `./tests/run.sh`: pass, 0 tests / 0 failures; exit 0.
- Temporary intentional failing test: correctly reported 1 failure and exited 1; removed afterward.
- `NVIM=/definitely/not/a/neovim ./tests/run.sh`: correctly reported missing executable and exited 127.
- `git diff --check`: pass. No deviations; no temp files remain.
- Environment note: Neovim 0.11.6; 0.12+ remains required for final smoke validation.

### 2.1 — Prose settings module
- Status: done; implemented `lua/novelist/settings.lua` and `tests/unit/settings_test.lua`.
- Files: `lua/novelist/settings.lua` (1–106), `tests/unit/settings_test.lua` (1–144), `planning/tasks/1.2.1.todo.md` (checked steps).
- API: `require('novelist.settings').apply(bufnr, settings)` returns true when applied and false for invalid/disabled/unsupported/opt-out buffers.
- Behavior: defaults applied locally; configurable `enabled`, `filetypes`, `spell`, `spelllang`, `wrap`, `linebreak`, `breakindent`, and `textwidth`.
- Tests: `./tests/run.sh` — pass, 6 tests / 0 failures.
- Deviations: none.
- Gotchas: wrap/spell/linebreak/breakindent are window-local in Neovim, so visible-buffer local options use the buffer's window when buffer-scoped setting is unavailable; integration should call during FileType/current-buffer lifecycle.
