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
| 2 | 3.2.1 Explicit command and location-list integration | pending | Depends on 3.1.1 |
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
