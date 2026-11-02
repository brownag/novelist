# State — Orchestration 4

Resume from this file and `planning/EXECUTION_PLAN_4.md`.

## Baseline
- [x] Repo `/home/andrew/workspace/novelist`; current HEAD `87f78fb`.
- [x] Confirmed Vale 3.20.0 CLI help: `[options] [input...]`; `--ext` and `--path` associate context with stdin.
- [x] Prior controlled smoke observed `--path=<draft>` + stdin + no positional input finds a repetition (exit 1), while trailing `-` yields `{}` (exit 0). At execution baseline the current adapter already omitted `-`; plan/task assertion that it remained was stale.
- [x] `make test` baseline after Plan 3 implementation: 49 passed, 0 failed.
- [x] Plan 3 documentation files are intentionally uncommitted while this follow-up closes the discovered smoke defect: `README.md`, `doc/novelist.txt`, plus `planning/STATE_3.md` and `planning/tasks/3.3.1.todo.md`.
- [x] Rechecked git status before implementation; preserved unrelated/previous-plan changes.

## Wave board
| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 4.1.1 Correct Vale stdin argv | complete | No-context argv assertion; source already omitted `-` |

## Task reports
<!-- Append each worker report under its task heading; keep each report <=15 lines. -->

## 4.1.1
- Status: complete; no commit.
- Changed: `tests/unit/vale_test.lua` adds a no-context argv assertion; named/unnamed context and stdin checks retained. Updated task record.
- Baseline: Vale 3.20.0; Neovim 0.12.5; `./tests/run.sh` → 49 passed, 0 failed.
- Validation: post-edit `./tests/run.sh` → 49 passed, 0 failed; `git diff --check` passed.
- Controlled CLI: `printf ... | vale --output=JSON --path="$tmp/draft.md"` from temp-project cwd; error-level finding JSON, exit 1; clean JSON `{}`, exit 0.
- Headless command: `nvim --headless -u NONE --cmd "set rtp+=$repo" -c "lua dofile('$tmp/smoke.lua')" -c 'qa!'`; finding loclist count 1; clean loclist count 0/no-findings message; quickfix unchanged.
- Temp fixture was removed and absence confirmed. No staged files.
- Deviation: execution plan/task claimed current source and named/unnamed tests still had `-`; they already omitted it. Only missing no-context test was added; no `vale.lua` edit.
- Gotcha: warning-level fixture yielded a finding with exit 0; temporary style was set to error level for the specified exit-1 proof.
