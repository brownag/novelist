# Novelist — Master Plan

## Purpose

This document consolidates the original product scope and implementation sequence recorded in `EXECUTION_PLAN_1.md`, the task records, and `STATE_1.md`. Use it as the durable roadmap and intake for future `/plan-wave` sessions. It is not itself an execution plan: each approved body of new work should be turned into a numbered `EXECUTION_PLAN_N.md`, `PROMPT_TEMPLATE_N.md`, and `STATE_N.md` set by `/plan-wave`, based on the repository's current state at that time.

## Product goal

`novelist` is a standalone, dependency-free Lua Neovim plugin for prose writers. It provides configurable local prose settings and a lightweight revision cockpit for Markdown/plain-text drafts: heading-based section navigation, section/document word counts, and configurable standalone story/revision markers. It does not infer story meaning or provide grammar/style checking.

## Durable scope and constraints

- Target Neovim 0.12+; do not treat tests on an older runtime as target-version validation.
- Keep the plugin standalone Lua, with no required third-party dependencies.
- Parse buffer lines directly; keep parsing logic separate from Neovim UI/lifecycle integration.
- Markdown and plain text are the initial supported formats. Org/Neorg and other filetypes are deferred unless explicitly brought into a future plan.
- Apply prose settings locally, respect global and per-buffer opt-outs, use visual rather than hard wrapping, and avoid default keymaps.
- Expose workflow through named user commands. Default marker names are `who`, `what`, `where`, `when`, `why`, and `todo`; descriptions are display metadata and values remain writer-authored text.
- See accepted constraints in [ADR 0001](../docs/decisions/0001-dependency-free-lua-plugin-architecture.md) and [ADR 0002](../docs/decisions/0002-user-respecting-prose-settings-and-command-ux.md).

## Initial implementation sequence (Orchestration 1)

This sequence is preserved as a completed historical baseline, not a queue to rerun:

| Sequence | Workstream | Original tasks | Recorded outcome |
|---|---|---|---|
| 1 | Establish plugin layout and dependency-free headless test harness | 1.1 | Done; task record at `tasks/1.1.todo.md` |
| 2 | Implement prose settings and pure heading/count/marker parsing | 2.1, 2.2 (independent after 1.1) | Done; task records at `tasks/1.2.1.todo.md` and `tasks/1.2.2.todo.md` |
| 3 | Integrate public setup, FileType lifecycle, and named commands | 3.1 | Done; task record at `tasks/1.3.1.todo.md` |
| 4 | Write user/help documentation and perform release-facing validation | 4.1 | Done; task record at `tasks/1.4.1.todo.md` |

The detailed task contracts and original decisions remain in `EXECUTION_PLAN_1.md`; execution reports are in `STATE_1.md`. Historical task IDs are inconsistent: the plan calls the follow-on tasks `2.1`, `2.2`, `3.1`, and `4.1`, while task filenames/headings use `1.2.1`, `1.2.2`, `1.3.1`, and `1.4.1`. Preserve or explicitly map IDs if referencing these records. Consult them for historical rationale, not as proof that the repository still matches the original baseline.

## Current follow-up record

`planning/TODO_20261102.md` (archived from the repository-root `TODO.md`) records later test-helper/marker cleanup, Neovim 0.12.6 smoke validation, and repository housekeeping follow-ups. Its checkboxes and notes are the latest recorded completion evidence for those items. `STATE_1.md` and the validation sections of ADRs 0001/0002 predate that follow-up and still describe the target-version smoke test as outstanding; treat those statements as historical and verify the newer explicit validation record rather than carrying stale status forward. The old `PROMPT_TEMPLATE_1.md` also says no `AGENTS.md` exists; that guidance is obsolete now that the root `AGENTS.md` is present. Do not reuse the old template unedited for new orchestration.

Before preparing another wave plan, inspect `git status`, current tests, README/help, accepted ADRs, and the relevant TODOs. Do not assume the historical state is current or reopen completed tasks without evidence of a regression.

## Research notes (context, not scheduled work)

`planning/research/` contains exploratory reports on Rust Neovim plugin approaches (`mlua` and `nvim-oxi`). These do not change the accepted Lua architecture or create implementation commitments; the execution plan explicitly chose standalone Lua and deferred required dependencies.

## Future roadmap phases

The user-selected planning order is **5 → 1 → 2 → 3 → 4**. Each phase is a roadmap boundary for a future `/plan-wave` session, not a pre-approved implementation plan. The phase number retains the earlier group number; execution plan numbering remains sequential (the next orchestration set is 2). Features listed below remain candidates until scoped and approved in their own `/plan-wave` session.

| Order | Phase | Candidate scope | Boundaries and dependencies |
|---|---|---|---|
| 1 | **Integrations and Interaction** (group 5) | Plugin-manager-specific integration where it provides clear value; optional parser/runtime integrations; user-configurable keymaps. | Preserve ADR 0001: no required third-party dependencies. Preserve ADR 0002: no default keymaps. Optional integrations must not make the standalone plugin unusable. This is the first phase by user direction. |
| 2 | **Writing Assistance** (group 1) | Grammar/style integrations such as Vale or LTeX/LanguageTool; automatic narrative interpretation as a separate or explicitly optional direction. | Prioritize grammar/style integration. Keep interpretation separate/optional because the current contract treats marker values and story facts as writer-authored text. Reconcile any interpretation proposal with accepted ADRs before planning it. |
| 3 | **Manuscript Workflow** (group 2) | Manuscript compilation/export/submission formatting; focus mode and Markdown rendering. | Treat compilation/export separately from focus/rendering so a future plan can scope and sequence them independently. Companion integrations should remain optional unless a decision explicitly supersedes current architecture. |
| 4 | **Story Organization** (group 3) | Story-bible/vault features; backlinks and connected reference material; timeline consistency analysis. | Keep these as distinct candidate workstreams; they may need different data models or integrations. Resolve storage and scope before drafting implementation tasks. |
| 5 | **Format Support** (group 4) | Additional format adapters, including Org, Neorg, or other formats beyond Markdown/plain text. | Treat each format as a separate candidate adapter. Markdown/plain text remain the baseline; decide which additional formats merit support in this phase's `/plan-wave` session. |

### Future phase planning workflow

For each phase, in the order above:

1. Re-read this roadmap, `planning/TODO_20261102.md`, current code/tests/docs, `docs/decisions/README.md`, and the accepted ADRs. Check which candidate work is still relevant and avoid assuming prior status is current.
2. Use `/plan-wave` to establish a bounded goal, resolve the phase's choices with the user, and create the next numbered `EXECUTION_PLAN_N.md`, `PROMPT_TEMPLATE_N.md`, and `STATE_N.md` set with dependencies and acceptance criteria.
3. Do not silently pull candidate work from later phases into an earlier plan. If a dependency requires changing phase order, ask the user and record the decision.
4. After implementation, update task/state evidence. Revise this master plan only for durable scope/order changes, not transient task status.

If any proposed implementation conflicts with an accepted ADR, explicitly resolve whether the plan complies or supersedes that ADR, and record the target ADR ID and required update in the approved plan.
