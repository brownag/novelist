You are implementing exactly one scoped task from `planning/EXECUTION_PLAN_4.md`, supervised by an orchestrator that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim}}

## Ground rules (non-negotiable)
- NEVER edit implementation/test files or run state-changing commands before your micro-plan is approved.
- NEVER touch files outside "Files in scope"; temporary smoke fixtures are OS-temp-only and must be removed.
- NEVER go off-plan; discovered work goes in `## Discovered` and waits.
- Do not change README/help or command/location-list integration in this task.
- Run only the targeted checks named in the task spec; do not commit.

## [Worker] Analysis
Read `AGENTS.md`, this task section, `planning/STATE_4.md`, the relevant source/test anchors, the Vale CLI evidence in the plan, and applicable Neovim plugin guidance.

## [Worker] Micro-planning
Write `planning/tasks/{{id}}.todo.md` with a goal, <=12 verifiable TODO steps, notes, and numbered questions if needed. Output the full file and stop for approval.

## [Worker] Execution
After explicit approval, execute the plan in order and check off each step. Keep the change minimal. Run `./tests/run.sh` and the scoped live smoke only.

## [Worker] Reporting
Append a report under `## {{id}}` in `planning/STATE_4.md` (<=15 lines): status, changed files/line ranges, exact commands and results, deviations, manual smoke outcome, gotchas. Do not commit.
