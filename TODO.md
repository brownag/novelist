# TODO

## Goal
Gather primary-source evidence and open design decisions for the **Integrations and Interaction** roadmap phase, so a later `/plan-wave` session can define a bounded implementation plan without changing plugin code.

## Tasks

### 1. Establish the current integration baseline
- [x] Inspect the current public setup/configuration API, command registration, filetype behavior, package/runtime layout, tests, README, and Neovim help for integration and interaction extension points.
- [x] Record applicable constraints from accepted ADRs 0001 and 0002, including dependency-free operation and no default keymaps.

### 2. Research candidate integration approaches
- [ ] Use primary sources (official Neovim documentation and first-party plugin-manager/parser documentation or source) to investigate plugin-manager-specific integration, optional parser/runtime integrations, and user-configurable keymaps.
- [ ] Compare only options relevant to this plugin; distinguish documented facts from assumptions, trade-offs, and unresolved choices.
- [ ] Verify that every cited technical claim links to the source that owns it; do not treat secondary articles as authoritative evidence.

### 3. Produce a scoping brief for the next `/plan-wave`
- [ ] Save one Markdown brief under `planning/research/` describing the baseline, candidate approaches, ADR constraints, risks/dependencies, and decisions the user must make during `/plan-wave`.
- [ ] Keep plugin code, tests, README/help, ADRs, and orchestration plans unchanged; this task gathers evidence only.
- [ ] Check that the brief's recommendations preserve optional integrations and user-configured mappings unless the user explicitly chooses otherwise.
- [ ] Run `git diff --check` and verify only `TODO.md` and the new scoping brief changed.

## Notes
- Scope is the first roadmap phase only: **Integrations and Interaction**. Do not research or plan implementation for Writing Assistance, Manuscript Workflow, Story Organization, or Format Support.
- The agreed candidate areas are plugin-manager-specific integration where valuable, optional parser/runtime integrations, and user-configurable keymaps.
- Preserve the accepted constraints: no required third-party dependency (ADR 0001) and no default keymaps (ADR 0002). Do not propose superseding either ADR; surface any apparent conflict as an explicit user decision.
- Do not implement features or create `EXECUTION_PLAN_2.md`, `PROMPT_TEMPLATE_2.md`, or `STATE_2.md` in this scoping task.
- The current suite baseline is `make test`: 22 passed, 0 failed. This is research/scoping work, so no implementation tests are expected.
