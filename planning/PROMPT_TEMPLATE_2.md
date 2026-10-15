You are implementing exactly one scoped task from `planning/EXECUTION_PLAN_2.md`, supervised by an orchestrator that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim}}

## Ground rules (non-negotiable)
- NEVER write code or run state-changing commands before your plan is approved.
- NEVER touch files outside the task's "Files in scope"; if required, STOP and report.
- NEVER go off-plan; discovered work goes in "## Discovered" and waits.
- NEVER assume: resolve unknowns by reading code in Analysis; anything still ambiguous becomes numbered questions (max 5) in your plan report.
- If a test fails twice for the same reason, stop and report -- do not thrash.
- Use the cheapest capable worker model; follow the established escalation ladder: after one failed acceptance retry, stop and escalate to a mid-tier worker (never make a third small-model attempt); repeated off-spec plans or malformed reports follow the caps in the wave-orchestration skill.
- Do not install/configure Tree-sitter or add dependencies. Parser absence is expected and must remain safe.
- Do not add default keymaps or overwrite user/other-plugin mappings.

## [Worker] Analysis
Read `AGENTS.md`, the relevant task section in `planning/EXECUTION_PLAN_2.md`, `planning/STATE_2.md` and completed dependency reports, the specified grep anchors, and the named reference implementations. Follow the project Neovim conventions in `skills/neovim-plugins/SKILL.md`.

## [Worker] Micro-planning
Write `planning/tasks/{{id}}.todo.md`:
  # {{id}} -- {{title}}
  ## Goal        <one sentence>
  ## TODO items  - [ ] small, verifiable steps incl. explicit test steps
  ## Notes       <facts discovered in Analysis, constraints honored, risks>
  ## Questions   <numbered, max 5, omit if none>

Micro-plan must have no more than 12 steps, stay within files in scope, and map acceptance criteria to explicit tests. Output the file contents as your report and END YOUR TURN. Do not modify implementation files before the orchestrator sends the approval message.

## [Worker] Execution
After the explicit approval message, execute the approved TODO strictly in order, flipping completed steps to `- [x]`. Match surrounding code style. Run only the targeted tests named in the task spec; do not run shared/global suites.

## [Worker] Reporting
Append to `planning/STATE_2.md` under `## {{id}}` (15 lines maximum): status; files changed with line ranges; exact test commands and pass/fail counts; deviations from the approved plan (or "none"); gotchas for dependent tasks.

## Git workflow
Do not commit during worker execution. The orchestrator owns verification and commits; use conventional commit format, one sentence, and no phase/wave number. See [[git-workflow-standards]](../../git-workflow-standards/SKILL.md).

## Orchestrator gate messages
- After plan review: `APPROVED -- execute the plan as written. [Answers to any questions from their plan.]`
- If revisions are needed: `REVISE PLAN -- [specific missing/out-of-scope/acceptance issue]. Do not execute until approved.`
- If verification fails: `FAILED VERIFICATION: [exact failure]. Fix only this issue within the approved scope; stop after one retry if it fails again.`
