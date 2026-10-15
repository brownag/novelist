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

`TODO.md` at repository root records later test-helper/marker cleanup, Neovim 0.12.6 smoke validation, and repository housekeeping follow-ups. Its checkboxes and notes are the latest recorded completion evidence for those items. `STATE_1.md` and the validation sections of ADRs 0001/0002 predate that follow-up and still describe the target-version smoke test as outstanding; treat those statements as historical and verify the newer explicit validation record rather than carrying stale status forward. The old `PROMPT_TEMPLATE_1.md` also says no `AGENTS.md` exists; that guidance is obsolete now that the root `AGENTS.md` is present. Do not reuse the old template unedited for new orchestration.

Before preparing another wave plan, inspect `git status`, current tests, README/help, accepted ADRs, and the relevant TODOs. Do not assume the historical state is current or reopen completed tasks without evidence of a regression.

## Research notes (context, not scheduled work)

`planning/research/` contains exploratory reports on Rust Neovim plugin approaches (`mlua` and `nvim-oxi`). These do not change the accepted Lua architecture or create implementation commitments; the execution plan explicitly chose standalone Lua and deferred required dependencies.

## Deferred directions (not approved implementation scope)

The original plan explicitly deferred these capabilities. Treat each as a candidate for discussion, not an implicit commitment or backlog item:

- Grammar/style checking (Vale, LTeX/LanguageTool).
- Manuscript compilation, export, or submission formatting.
- Org/Neorg and other non-Markdown/plain-text filetypes.
- Story-bible/vault features, backlinks, timeline consistency analysis, or automatic narrative interpretation.
- Required Tree-sitter, plugin-manager-specific integration, default keymaps, focus mode, or Markdown rendering.

A future `/plan-wave` session must establish a concrete goal and resolve scope/order decisions with the user before drafting execution artifacts. If a proposal conflicts with an accepted ADR, resolve that explicitly and update/supersede the ADR as part of the approved plan.

## How to continue

1. Review this roadmap, `TODO.md`, current code/tests/docs, `docs/decisions/README.md`, and relevant accepted ADRs.
2. Identify one bounded, user-approved next goal; distinguish facts from choices that need user decisions.
3. Run `/plan-wave` to produce the next numbered execution-plan artifact set, with dependencies and acceptance criteria based on the current repository.
4. After implementation, update task/state evidence and revise this master plan only when durable scope/order changes—not for transient task status.
