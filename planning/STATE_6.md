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
| 1 | 6.1.1 Run the Neovim 0.12+ smoke gate and record results | pass | Attempt 1 failed at step 8; code fix applied; attempt 2 passes scripted 1–17 and user visual check (10–12, 15) |

## Gate summary
- Gate status: **PASS.** Scripted steps 1–17 pass on attempt 2; user confirmed visual steps 10–12 and 15.
- Attempt 1 failed at step 8 (see `## 6.1.1` below). Attempt 2 ran on the fixed tree.

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

## 6.1.1 attempt 2 (after fix)
- Fix: `lua/novelist/commands.lua` `list_markers` re-focuses the source window after `copen`. Test added: `tests/unit/integration_test.lua` "marker listing keeps focus in the source window so a filter can follow". Red before fix, green after.
- Docs: `README.md` command table and `doc/novelist.txt` `:NovelistMarkers` state that focus stays in the source window.
- `make test`: 50 passed, 0 failed. `make docs-check`: exit 0. `git diff --check`: clean.
- Scripted runs (headless, `/usr/bin/nvim` 0.12.6; Vale 3.24.0; fresh `mktemp` fixture, removed):
  - 1–9 `pass`. Step 6: `section words: 6, document words: 10`. Step 8: unfiltered 2 items; `todo` 1 item (line 4).
  - 10 `pass` (scripted): outline opens beside source (same top row, different column); rows `Opening [1]`, `@who… [2]`, `@todo… [4]`, `Turn [6]`.
  - 11 `pass`: Enter lands on each row's line; source edit leaves outline unchanged; re-run shows `Turn [7]`.
  - 12 `pass`: stubbed parser and plain-text buffer both show `novelist: markdown parser unavailable; showing headings only`.
  - 13a `pass`: plain `setup()` maps none of the five. 13b `pass`: `suggested` maps five with matching desc/rhs. 13c `pass`: `word_count` override moves to `<leader>nc`; `markers = false` unmaps `<leader>nm`; other three unchanged.
  - 14 `pass`: fixture only; repo has no `.vale.ini`.
  - 15 `pass` (scripted): loclist has `Avoid the word 'foobar'.` at line 8; global quickfix unchanged.
  - 16 `pass` (scripted): unsaved line 9 finding shown; disk file still clean.
  - 17 `pass` (scripted): `novelist: no Vale findings`; no loclist items; no loclist window.
- Harness correction (not a product change): step 10's first check asserted a top-level `row` layout. That fails once step 8 leaves a quickfix window below, so the check became geometry (same top row, different columns).
- Visual check (user): steps 10, 11, 12, 15 confirmed pass. Gate closed.
