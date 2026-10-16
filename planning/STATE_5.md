# State — Orchestration 5

Resume from this file and `planning/EXECUTION_PLAN_5.md`.

## Baseline
- [x] Repo `/home/andrew/workspace/novelist`; HEAD `a7e5158` (`fix(vale): lint unsaved stdin correctly`).
- [x] Existing user changes are Plan 4 artifacts and `tests/unit/vale_test.lua`; preserve them.
- [x] `make test` → 49 passed, 0 failed.
- [x] `make docs-check` passed; no generated tags left behind.
- [x] Neovim runtime available: 0.12.5.
- [x] Accepted ADRs 0001 and 0002 reviewed; neither is superseded.

## Wave board
| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 5.1.1 Safe local Makefile install/uninstall | complete | Temp `INSTALL_DIR` safety checks passed. |
| 2 | 5.2.1 README lazy.nvim and local install guidance | complete | README documents optional lazy.nvim and Make symlink installation. |

## Task reports
<!-- Append each worker report under its task heading; keep each report <=15 lines. -->

## 5.1.1
- Status: complete.
- Files changed: `Makefile`; `planning/tasks/5.1.1.todo.md`; this state report.
- `make`: passed; help lists `install` and `uninstall`.
- Temporary `INSTALL_DIR` Bash assertions: passed for absolute/relative overrides, correct symlink and repeat install, matching uninstall, and parent preservation.
- Conflict assertions: passed for unrelated file, unrelated symlink, and dangling symlink; install refused each unchanged and uninstall preserved each.
- `git diff --check`: passed.
- Initial temp-check attempt failed from malformed recipe continuation escaping; corrected before retry, all checks passed.
- Deviations: none to approved scope; no global test suite run (not required for this task).
- Gotchas: Always pass a temporary explicit `INSTALL_DIR` during validation; uninstall intentionally does not prune parents.

## 5.2.1
- Status: complete.
- Files changed: `README.md` lines 25-67; `planning/tasks/5.2.1.todo.md`; this state report.
- README retains manager-generic installation, adds a lazy.nvim `opts`/`cmd` spec, and documents Make symlink path, override, safety, and help availability.
- `make test`: passed, 49 passed / 0 failed.
- `make docs-check`: passed; pre-existing untracked `doc/tags` hash unchanged.
- `git diff --check`: passed.
- Deviations: none; no runtime, vimdoc, or test changes.
- Gotchas: lazy.nvim config is user-side only; Vale remains optional and is invoked explicitly.
