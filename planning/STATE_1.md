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
| 2 | 2.1 Prose settings module | done | Verified and committed (`7f7b8dd`) |
| 2 | 2.2 Heading, count, and marker parsing module | done | Verified and committed (`a4cabb5`) |
| 3 | 3.1 Public setup, settings lifecycle, and commands | implemented | Uncommitted; review/commit pending |
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

### 2.2 — Heading, count, and marker parsing module
- Status: done; implemented `lua/novelist/cockpit.lua` and `tests/unit/cockpit_test.lua`; committed as `a4cabb5`.
- Files: cockpit module (1–235), tests (1–176), `planning/tasks/1.2.2.todo.md` (checked steps).
- `./tests/run.sh`: pass, 8 tests / 0 failures; `git diff --check`: pass.
- Covers ATX hierarchy/sections, navigation, word counts, default/configured markers, exclusions, occurrences and line numbers.
- Deviations: none. Test file adds `root/lua` to package.path because harness only adds repository root.

### 3.1 — Public setup, settings lifecycle, and commands
- Status: implemented; uncommitted, review pending.
- Files: `plugin/novelist.lua` (1), `lua/novelist/init.lua` (1–92), `lua/novelist/commands.lua` (1–149), `tests/unit/integration_test.lua` (1–264), `planning/tasks/1.3.1.todo.md` checked.
- Public API: runtime plugin calls `require('novelist').setup()`; repeated setup updates config and recreates one FileType autocmd per supported filetype pattern.
- Commands: `NovelistSceneNext`, `NovelistScenePrev`, `NovelistWordCount`, `NovelistMarkers [name]`; no mappings added.
- Tests added: integration coverage for repeated setup, empty `filetypes={}` replacement, FileType settings, unsupported/opt-out buffers, command navigation/counts/quickfix, no-match handling, and no keymaps.
- `./tests/run.sh`: pass, 22 tests / 0 failures on Neovim 0.11.6.
- Deviations: none.
- Gotchas: FileType autocmd inspection returns two entries for default `markdown` and `text` patterns; command no-heading/no-match warnings appear in test output via `vim.notify`.
