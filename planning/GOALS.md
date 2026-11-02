# Project Goals (`planning/GOALS.md`)

Last Updated: 2026-11-01
Source State: STATE_5.md

## Circled Goal (Active)

- **[G1]** Phase 1 (Integrations and Interaction) passes the Neovim 0.12+ manual smoke gate on HEAD, and the result is recorded.
  - Why now: It is the only gate between Phase 1 and every later roadmap phase, and it can be completed within 24 hours.
  - Exit criteria: All 17 steps in README "Manual smoke test for Neovim 0.12+" pass on Neovim 0.12.6 (`/opt/nvim-linux-x86_64/bin/nvim`), with the outcome recorded in `planning/STATE_5.md`.
  - First action: Start `/opt/nvim-linux-x86_64/bin/nvim` with this repository on `runtimepath` and run README smoke steps 1–3.

## Sequenced Goals (Dependency DAG)

- **[G4]** The working tree holds only intended changes.
  - Depends on: none (committed on branch `test/vale-no-context-argv`: `df3481e`, `9a97807`, `bef5e8f`; `doc/tags` is generated and left untracked)

- **[G2]** `make install` and `make uninstall` safety is covered by automated tests under `tests/`.
  - Depends on: none (may run alongside G1)

- **[G3]** Accepted Phase 1 decisions are recorded as ADRs in `docs/decisions/`: optional external Vale adapter, Tree-sitter fallback, opt-in keymap preset, and symlink install.
  - Depends on: G1

- **[G5]** Writing Assistance is scoped as a `/plan-wave` session: LTeX/LanguageTool is evaluated against the existing Vale adapter.
  - Depends on: G1, G3

## Independent Backlog

- **[G6]** Stale planning status is corrected: `STATE_1.md`, `PROMPT_TEMPLATE_1.md`, ADR validation sections, and `MASTER_PLAN.md` phase status.

## Deferred

- **[G7]** Manuscript compilation and export are scoped separately.
  - Trigger: G5 is closed and the user starts Phase 3.

- **[G8]** Focus mode and Markdown rendering are scoped separately from G7.
  - Trigger: G5 is closed and the user starts Phase 3.

- **[G9]** Story-bible, backlink, and timeline features have a chosen storage model.
  - Trigger: The user makes a storage or data-model decision for Phase 4.

- **[G10]** Org and Neorg adapters are scoped as separate format adapters.
  - Trigger: The user starts Phase 5 or requests a specific format.

- **[G11]** Narrative interpretation of marker values is scoped as an explicit option.
  - Trigger: The user decides to extend the writer-authored-values contract, which requires reconciling it with the accepted ADRs.

## Blocked / Pruned

- **[G12]** Plugin-manager runtime adapters beyond lazy.nvim documentation.
  - Status: Pruned
  - Reason: Documentation and the Makefile symlink path cover the need; ADR 0001 keeps the plugin manager-independent.

- **[G13]** Plugin-installed default keymaps.
  - Status: Pruned
  - Reason: ADR 0002 forbids default keymaps; the opt-in `suggested` preset already exists.

- **[G14]** Vale or LTeX as a required dependency.
  - Status: Pruned
  - Reason: ADR 0001 requires dependency-free operation; these stay optional.
