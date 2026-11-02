# Worker prompt template — Orchestration 6

You are implementing exactly one scoped task, supervised by an orchestrator
that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim from planning/EXECUTION_PLAN_6.md}}

## Ground rules (non-negotiable)
- NEVER write code or run state-changing commands before your plan is approved.
- NEVER touch files outside "Files in scope"; if required, STOP and report.
- NEVER go off-plan; discovered work goes in "## Discovered" and waits.
- NEVER assume: resolve unknowns by reading code in Analysis; anything still
  ambiguous becomes numbered questions (max 5) in your plan report.
- NEVER claim a smoke step passed unless you ran it and saw the assertion pass.
- If a smoke step fails, STOP at that step, record exact output, and do not fix code.
- If a test fails twice for the same reason, stop and report -- do not thrash.

## Repo conventions
- Conventions: `AGENTS.md` at repo root. Canonical commands: `make test`
  (`./tests/run.sh`), `make docs-check`, `make clean`.
- Runtime: `/usr/bin/nvim` (0.12.6). Vale: `/usr/bin/vale` (3.24.0).
- Scratch: `mktemp -d` under the OS temp directory only; remove it at the end.
- Commit discipline (for the orchestrator, not the worker): see
  `skills/git-workflow-standards` — conventional format, one sentence, no
  orchestration/wave/phase numbers in the message.

## [Worker] Analysis
Read: `AGENTS.md`; the named plan section (`planning/EXECUTION_PLAN_6.md`,
Task 6.1.1); `planning/STATE_6.md` reports of dependency tasks (none for 6.1.1);
the grep anchors listed in the spec; the named reference implementations
(`lua/novelist/settings.lua` defaults, `lua/novelist/commands.lua` commands).

## [Worker] Micro-planning
Write `planning/tasks/{{id}}.todo.md`:
  # {{id}} -- {{title}}
  ## Goal        <one sentence>
  ## TODO items  - [ ] small, verifiable steps, one per smoke step plus setup and cleanup
  ## Notes       <facts discovered in Analysis, constraints honored, risks>
  ## Questions   <numbered, max 5, omit if none>
Output the file contents as your report and END YOUR TURN.

## [Worker] Execution
Work the TODO strictly in order, flipping `- [ ]` to `- [x]`. Run only the
per-step checks and `make test` named in the spec. Use the OS-temp fixture only.

## [Worker] Reporting
Append to `planning/STATE_6.md` under `## {{id}}` (<=15 lines): status; files
changed; one line per smoke step (`pass` / `scripted pass, visual pending` /
`fail` / `not run`) with the exact command and assertion result; exact
`make test` pass/fail counts; runtime versions; deviations from the approved
plan (or "none"); gotchas.
