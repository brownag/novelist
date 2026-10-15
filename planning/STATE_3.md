# State — Orchestration 3

Resume from this file and `planning/EXECUTION_PLAN_3.md`.

## Baseline checklist (before Wave 1)

- [x] Confirmed repo `/home/andrew/workspace/novelist`; working tree clean before plan artifacts.
- [x] Read root `AGENTS.md`, `skills/neovim-plugins/SKILL.md`, accepted ADRs 0001/0002, master plan, prior execution/state records, relevant source/tests/docs, and Vale scoping brief.
- [x] `make test`: 38 passed, 0 failed.
- [x] `make docs-check`: passed; generated `doc/tags` removed with `make clean`.
- [x] Runtime `/usr/bin/nvim`: Neovim 0.12.5.
- [x] Local `/usr/bin/vale` version 3.20.0; no repository `.vale.ini`; `vale ls-config` reports no config. Automated tests must not require this binary/config.
- [ ] Before implementation Wave 1, re-check `git status` and repeat baseline if implementation/environment changed.

## Wave board

| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 3.1.1 Vale process and diagnostic adapter | complete | Verified: 42 tests pass; report below |
| 2 | 3.2.1 Explicit command and location-list integration | complete | Verified: 49 tests pass; report below |
| 3 | 3.3.1 README/help documentation and manual smoke workflow | pending | Depends on 3.2.1 |

Maximum concurrent workers: 2. Tasks are sequential by wave; full suite and docs checks run serially at wave gates.

## Task reports

<!-- Append each worker report under its task heading; keep each report <=15 lines. -->

## 3.1.1

- Status: complete — Vale process/diagnostic adapter implemented and tested (no commit).
- Files changed (created): `lua/novelist/vale.lua` (1-96); `tests/unit/vale_test.lua` (1-165).
- Contract: `vale.check({ executable, lines, path?, ext? }, on_done)`; `on_done` receives `{ ok=true, diagnostics, code, stdout, stderr }` or `{ ok=false, error, code?, stdout?, stderr? }`. Diagnostic record: `{ path, line, col, end_col, severity, message, check, match }`. Injectable seam `vale.process(argv, stdin, on_exit)` defaults to `vim.system(argv, { stdin=stdin, text=true }, on_exit)`.
- Classification: exit 0/1 = success (JSON parsed; empty `{}` = zero diagnostics); any other/nil code = process error preserving `code`/`stdout`/`stderr`; malformed JSON = parse error; launch throw caught via `pcall` (covers missing executable). Argv: `{ exe, '--output=JSON', '--ext=<ext>'?, '--path=<path>'?, '-' }`; stdin = buffer lines joined with `\n`.
- Command: `./tests/run.sh` -> `Tests: 42 passed, 0 failed` (38 baseline + 4 new).
- Deviations: none.
- Gotchas for 3.2.1: adapter is intentionally UI-free (no loclist/notify/`vim.schedule`); integration owns captured window/buffer identity, scheduling editor work, loclist writes, and the `vale.executable` default. stdout JSON is path-keyed; record `path` is that key. Real stdin linting not locally verified (Vale 3.20.0 returned `{}` for piped stdin in an ad-hoc probe) — confirm at the 3.3.1 manual smoke gate.

## 3.2.1

- Status: complete — explicit `:NovelistVale` command with invoking-window location-list reporting (no commit).
- Files changed: `lua/novelist/init.lua` (`vale = { executable = 'vale' }` in `default_config`, line 46).
- Files changed: `lua/novelist/commands.lua` (`require('novelist.vale')` line 3; `vale_filetypes`/`vale_severity_types`/`vale_extension`/`vale_loclist_items`/`apply_vale_result`/`vale_command` lines 255-352; `NovelistVale` registration lines 382-385).
- Files changed: `tests/unit/integration_test.lua` (vale require line 6, vale helpers lines 20-64; 7 new tests lines 248-541).
- Behavior: markdown/text only (unsupported → WARN); captures winid/bufnr/lines/name plus `vale.executable` before launch; wraps the adapter callback in `vim.schedule`; writes the captured window's loclist via `setloclist(winid, ...)` and opens it with `nvim_win_call(winid, 'lopen')` only when findings exist; INFO notify on zero findings; process/parse errors notify ERROR and leave the loclist and quickfix untouched. Named buffer → `--path`; unnamed → `--ext=.md/.txt`.
- Lifecycle: if the captured window is closed or no longer shows the source buffer, results are dropped with a WARN; index switched-buffer and closure cases are tested.
- Command: `./tests/run.sh` -> `Tests: 49 passed, 0 failed` (42 baseline + 7 new).
- Deviations: none.
- Gotchas for 3.3.1: closing a loclist window with `lclose` does not clear the window's loclist contents (tests clear lists per case); document loclist-vs-quickfix isolation, unsupported-filetype behavior, and that real-Vale stdin smoke remains pending.

## 3.3.1

- Status: complete — README/vimdoc Vale documentation and manual smoke workflow delivered (no commit). Manual real-Vale smoke was attempted but did not verify findings; recorded below, not claimed as a pass.
- Files changed: `README.md` (overview + requirements; default config block and new `vale` options table; `:NovelistVale` command row; new "Vale (optional)" section; smoke steps 14-17); `doc/novelist.txt` (contents renumber + `|novelist-vale|`; overview + requirements; default config and `*novelist-vale-options*`; `*:NovelistVale*`; new VALE (OPTIONAL) section; smoke steps 14-17).
- Commands: `make test` -> 49 passed, 0 failed; `make docs-check` -> passed (generated `doc/tags` removed with `make clean`); `git status` -> only `README.md`, `doc/novelist.txt`, new `planning/tasks/3.3.1.todo.md`.
- Manual smoke (Neovim 0.12.5 headless, `/usr/bin/vale` 3.20.0, user-style `.vale.ini` in an OS temp project): performed, NOT passed. Vale flags a repeated word when reading a file and when reading piped stdin with `--path`/`--ext` and no positional argument (exit 1, finding), but returned `{}` (exit 0) for the argv form with a trailing `-` positional. Headless `:NovelistVale` on an unsaved named Markdown buffer ended with loclist count 0, message `novelist: no Vale findings`, and an empty quickfix.
- Deviations: none in documentation scope.
- Gotchas: real-Vale finding display is unverified against the current `lua/novelist/vale.lua` argv (the `-` positional vs Vale 3.20.0 stdin behavior). This is discovered, outside 3.3.1 file scope, and was not fixed. `make docs-check` leaves `doc/tags`; remove it with `make clean` unless tags are intentionally tracked.
