# State — Orchestration 6

Resume from this file and `planning/EXECUTION_PLAN_6.md`.

## Baseline
- [x] Repo `/home/andrew/workspace/novelist`; branch `test/vale-no-context-argv`; HEAD `bef5e8f`; `main` at `a28dec2`.
- [x] Neovim: `/usr/bin/nvim` reports `NVIM v0.12.6` (`/opt/nvim-linux-x86_64/bin/nvim` does not exist).
- [x] Vale: `/usr/bin/vale` version 3.24.0.
- [x] Markdown Tree-sitter parsers present under `~/.local/share/nvim/site/parser/`.
- [x] `make test` baseline: 49 passed, 0 failed (last run before this plan).
- [x] `make docs-check` exit 0 (run at wave 1, after the smoke run began).

## Wave board
| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 6.1.1 Run the Neovim 0.12+ smoke gate and record results | failed (gate open) | Stopped at step 8 per failure policy; steps 9–17 not run |

## Gate summary
- Gate status: **OPEN**. Step 8 failed; steps 9–17 `not run`.
- Steps 1–7: `pass` (scripted).
- Visual confirmation (steps 10–12, 15): not requested; it applies only after the scripted gate passes.

## Task reports
<!-- Append each worker report under its task heading; keep each report <=15 lines. -->

## 6.1.1
- Status: **failed at step 8**. Gate open. No repo code, test, or doc edits.
- Runtime: `NVIM v0.12.6` (`/usr/bin/nvim`); `vale version 3.24.0` (`/usr/bin/vale`).
- Fixture: `mktemp -d` under `/tmp`, removed; verified gone. Repo has no `.vale.ini` before or after.
- 1 `pass`: `vim.version` / rtp load from repo path.
- 2 `pass`: `:version` contains `NVIM v0.12.6`; `has('nvim-0.12')` = 1.
- 3 `pass`: sample buffer (from README step 5 block) set to `filetype=markdown`.
- 4 `pass`: spell/spelllang/wrap/linebreak/breakindent/textwidth equal `settings.defaults`.
- 5 `pass`: buffer lines equal README sample.
- 6 `pass`: `:NovelistWordCount` → `novelist: section words: 6, document words: 10` (hand count matches).
- 7 `pass`: SceneNext 1→6; ScenePrev 7→6; ScenePrev 3→1.
- 8 `fail`: `:NovelistMarkers` → 2 quickfix items (lnum 2, 4). Focus moves to the quickfix window (`buftype=quickfix`). Then `:NovelistMarkers todo` → `novelist: no markers found`, 0 items. Run from the source window instead: 1 item (lnum 4, `@todo: Seed the wax seal earlier`). The filter itself is correct; the second command scans the quickfix buffer.
- 9–17 `not run` (stop-on-first-failure).
- `make test`: 49 passed, 0 failed. `git diff --check`: clean.
- Deviation: none from the approved plan. Micro-TODO carries 15 items (one per step plus setup/cleanup) against the ≤12 guideline; the spec enumerates 17 steps, so it stayed.
- Gotcha for next attempt: README step 8 needs `wincmd p` (or equivalent) between the two commands, or a code fix. A fix is a separate user-approved task per the decision log.
