# Execution Plan 4 — Correct Vale stdin invocation

## Goal
Lock down the Vale adapter's stdin invocation exposed by Task 3.3.1's manual smoke: Vale 3.20.0 reads stdin when no positional input path is provided. The current working tree already omits the literal `-`; add a no-context argv test alongside existing named/unnamed context and stdin assertions. Preserve the intended unsaved-buffer behavior, context flags, asynchronous process handling, JSON parsing, and UI boundary.

## Scope
- Confirm the current adapter argv has no positional `-`; do not make a redundant source edit.
- Add deterministic adapter coverage for the no-context argv while retaining named/unnamed `--path`/`--ext` and stdin assertions.
- Re-run the real Neovim 0.12+ + Vale smoke against temporary, user-style configuration; capture exact observations and distinguish a pass from a failure.

Out of scope: command/location-list changes, docs changes, new dependencies, Vale installation/configuration in the repository, changes to Vale JSON parsing or diagnostic mapping unless required by smoke findings.

## Evidence and constraints
- Task 3.3.1 manual smoke used Neovim 0.12.5 and Vale 3.20.0 with a temporary `.vale.ini`/style fixture.
- `vale --help` says `vale [options] [input...]`, `--ext` associates an extension with stdin, and `--path` associates a path with stdin.
- Observed: piped stdin with `--path=<draft>` and no positional input returned a finding (exit 1); the identical invocation with a trailing `-` returned `{}` (exit 0). The live `:NovelistVale` consequently reported no findings and left its loclist empty.
- Recon during Plan 4 execution found that the checked-out adapter and named/unnamed tests already omit `-`; the source-fix and those expected-test changes described below were already present. The remaining implementation delta is the no-context assertion.
- Keep project dependency-free and do not modify repository Vale styles/config. Any smoke fixture must be created under OS temp and removed afterward.
- The implementation commit for the old argv must remain in history; make a focused follow-up commit.

## Wave table
| Wave | Task | Purpose | Dependencies |
|---|---|---|---|
| 1 | `4.1.1` | Correct stdin argv and prove it with deterministic tests plus live smoke | — |

## Task specification

### Task 4.1.1 — Correct Vale stdin argv
- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `tests/unit/vale_test.lua` (add no-context argv assertion only).
- **Can create:** temporary Vale config/style, draft, and headless Neovim script only under the OS temp directory; remove them after smoke. Update `planning/tasks/4.1.1.todo.md` and append report to `planning/STATE_4.md`.
- **Depends on:** none (failing smoke evidence in this plan is the input).
- **Spec:** Preserve the existing `M.build_argv(opts)` behavior: Vale receives `--output=JSON`, optional `--ext=<ext>` or `--path=<path>`, and no positional filename/`-`; stdin remains the current buffer text via `vim.system` options. Add a test for argv with no context, expecting `{ 'vale', '--output=JSON' }`; retain existing named/unnamed argv and stdin assertions. Do not modify command or loclist integration, docs, JSON parsing, user config, or Vale styles in the repository.
- **Anchors:** `M.build_argv` and `M.process` in `lua/novelist/vale.lua`; argv/stdin coverage in `tests/unit/vale_test.lua`; the exact CLI syntax and observed smoke failure recorded above.
- **Acceptance:** `./tests/run.sh` passes and includes the no-context argv assertion. A controlled CLI check confirms stdin with `--path` and no positional arg yields a finding (exit 1) and with alert-free text yields no findings (exit 0). Then run `:NovelistVale` in Neovim 0.12.5 against that temporary user-configured project with a finding and an alert-free buffer; findings populate the invoking window's loclist, no-finding run reports zero, and global quickfix remains unchanged. Record commands/outcomes; if any manual check cannot be completed, state that without claiming a pass.
- **Targeted test:** `./tests/run.sh`; focused real Vale + headless Neovim smoke as above.

## Risks
- Vale versions may differ in stdin behavior; command help and the local binary support the no-positional invocation.
- The temporary rule/config must be isolated and deterministic; do not use network or modify repo files.
