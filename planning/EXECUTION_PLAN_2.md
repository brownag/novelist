# Execution Plan 2 — Document map and opt-in interaction presets

## Goal & Scope

### Goal

Add a lightweight Markdown document map that presents headings and selected structural elements in a navigable outline, using Tree-sitter only when the user already has a usable Markdown parser; retain standalone behavior with a reduced outline when it is unavailable. Add a separately opt-in, customizable suggested global mapping preset for Novelist commands. Preserve the existing dependency-free Lua architecture and no-default-keymaps contract.

### In scope

- A `:NovelistDocumentMap` command opening a navigable outline in a vertical split while keeping the source visible.
- Hierarchical headings and (when Markdown Tree-sitter parsing is available) fenced code blocks, lists, blockquotes, and tables; include recognized configured Novelist marker lines.
- Heading-only structural fallback when Tree-sitter or the Markdown parser is unavailable or errors; markers may still be listed using the existing line parser.
- Outline entries with concise labels and source line numbers; Enter jumps to the source location. Re-running the command refreshes the outline; no live edit tracking.
- A single opt-in `suggested` mapping preset covering the existing four commands and `:NovelistDocumentMap`.
- Per-action key/mode/description customization and `false` to disable a suggested action. Global mappings, Normal mode by default; do not install anything unless explicitly opted in.
- Conflict-safe mapping installation and cleanup/update of Novelist-owned mappings across repeated `setup()` calls.
- README/help documentation, automated tests for parser-present and parser-unavailable paths, and a manual UI smoke test.

### Out of scope / deferred

- Plugin-manager-specific runtime adapters or manager-specific examples.
- Installing/configuring Tree-sitter or parsers; any required third-party dependency.
- Rich inline syntax, thematic breaks, a full Markdown preview, live outline updates, or non-Markdown rich parsing.
- Buffer-local mapping lifecycle, multiple named mapping presets, and default keymaps.
- Writing Assistance, Manuscript Workflow, Story Organization, and additional format support.

### Verbatim constraints and user statements

- Master plan constraint: “Keep the plugin standalone Lua, with no required third-party dependencies.”
- Master plan constraint: “Apply prose settings locally, respect global and per-buffer opt-outs, use visual rather than hard wrapping, and avoid default keymaps.”
- User: “yes, i am thinking some sort of helper for setting it up and easily setting up loadouts/\"defaults\" for different cases that cover relevant use cases”
- User: “yes exactly opt in mapping focused presets and then at least one \"suggested\" set that shows how users can customize”
- User: “i actually would like to have it to be able to map out a document for visualization and structure. i think building the minimal bones of it will be a valuable thing to build off”
- User accepted headings plus richer structures; selected fenced code blocks, lists, blockquotes, markers, and tables, while not prioritizing inline syntax.
- User accepted an optional Tree-sitter path with a useful reduced fallback, an outline scratch buffer, refresh on command invocation, a named command, and source navigation.
- User agreed to the suggested `<leader>n` mappings listed in this plan and the conflict behavior specified below.
- User agreed to automated fallback coverage plus a manual Neovim 0.12+ UI smoke test and a maximum of two concurrent workers.

## Decision log (2026-10-15)

1. **Mapping preset:** ship one opt-in `suggested` preset, not multiple workflow presets. Plain `setup()` installs no mappings.
2. **Suggested keys:** Normal mode: `<leader>nn` next section, `<leader>np` previous section, `<leader>nw` word count, `<leader>nm` markers, `<leader>no` document map.
3. **Mapping configuration:** opt in with `keymaps = { preset = 'suggested', mappings = { ... } }`; mapping keys are action IDs (`scene_next`, `scene_prev`, `word_count`, `markers`, `document_map`). Each value may be `false` or a table overriding `lhs`, `mode`, and/or `desc`. Default mode is `n`; mappings are global.
4. **Mapping safety:** existing user/other-plugin mappings win; skip conflicts and report them. Repeated setup updates/removes only mappings Novelist installed, not unrelated mappings.
5. **Document map:** command is `:NovelistDocumentMap`; open a dedicated scratch outline in a vertical split. Show nested structure, concise labels, and source line numbers; Enter jumps to the source line. Re-running refreshes; no live updates.
6. **Structure:** Markdown headings plus fenced code blocks, lists, blockquotes, and tables when Tree-sitter Markdown parsing is available. Include configured recognized standalone marker lines. No inline syntax requirement.
7. **Optional parser:** do not install or configure Tree-sitter/parser. For plain text, absent parser, or parser failure, provide heading-only structural outline; recognized markers can still be found through existing line-based marker parsing. Clearly indicate richer Markdown structure is unavailable.
8. **Scope exclusions:** no manager-specific integration/examples, multiple presets, buffer-local mapping lifecycle, live refresh, or additional formats in this plan.
9. **Ordering:** implement the document map command before the suggested mappings, so the final preset includes all five commands.
10. **Acceptance:** automated tests cover parser-present and parser-absent/failure behavior; require manual UI smoke validation under Neovim 0.12+ for split rendering and source jumps.
11. **Parallelism:** maximum two concurrent workers, carrying forward the established orchestration limit.

## Reconnaissance

- Repository: `/home/andrew/workspace/novelist`; working tree clean at intake. Current history includes the planning/master/research commits. No local edits were present.
- Conventions: root `AGENTS.md`; dependency-free Lua plugin; canonical commands `make test`, `make docs-check`, `make clean`. `skills/neovim-plugins/SKILL.md` says use `vim.keymap.set`, provide descriptions, test in real headless Neovim, keep README/help aligned, and make optional dependencies graceful.
- Entry points and sizes: `plugin/novelist.lua` (1 line); `lua/novelist/init.lua` (92); `commands.lua` (149); `cockpit.lua` (217); tests harness `tests/helpers.lua` (145), runner `tests/run.lua` (6); integration tests (198); README (177); vimdoc (257).
- Existing integration: `init.lua` owns setup/config merge and `FileType` lifecycle; `commands.lua` registers four commands; `cockpit.lua` parses headings and configured markers from lines. Tests are dependency-free and headless, with public setup/command tests in `tests/unit/integration_test.lua`.
- Reference implementations: setup and repeat-registration behavior in `lua/novelist/init.lua`; named-command conventions in `lua/novelist/commands.lua`; pure heading/marker behavior in `lua/novelist/cockpit.lua`; buffer and cleanup test helpers in `tests/helpers.lua`.
- ADRs: accepted ADR 0001 requires standalone Lua, no required third-party dependencies, and separation of parsing from Neovim integration. ADR 0002 requires no default mappings and user-respecting local settings/commands. This plan complies; neither ADR is superseded.
- Baseline: `make test` passes, 22 passed / 0 failed. `make docs-check` passes; generated tags removed with `make clean`. `/usr/bin/nvim` is Neovim 0.12.5. `vim.treesitter.get_parser(0, 'markdown')` is available in the current runtime; text has no matching parser. The target user-accepted validation remains Neovim 0.12+.
- Tree-sitter parser availability is not guaranteed even when the API exists; catch parser creation/parse failures and preserve fallback behavior. Do not add or configure parser dependencies.

## Wave table

| Wave | Tasks | Purpose | Dependencies |
|---|---|---|---|
| 1 | `2.1.1` | Extract a testable document outline model with optional Markdown structure | — |
| 2 | `2.2.1` | Render the outline and expose `:NovelistDocumentMap` | 2.1.1 |
| 3 | `2.3.1` | Add opt-in suggested mappings and safe setup lifecycle | 2.2.1 |
| 4 | `2.4.1` | Document configuration, command, fallback, and manual smoke workflow | 2.3.1 |

Tasks are sequential because the integration stages depend on the prior public surface. Maximum concurrency remains two; no wave contains overlapping file scopes.

## Task specifications

### Task 2.1.1 — Document structure model with optional Tree-sitter

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `lua/novelist/document_map.lua`, `tests/unit/document_map_test.lua`.
- **Can create:** none.
- **Depends on:** none.
- **Spec:** Build a model of outline entries from a buffer's lines and metadata, separate from rendering. Always provide Markdown ATX headings in a hierarchy. When Markdown Tree-sitter parsing succeeds, use heading nodes from that tree (so heading-like text inside code blocks is not misclassified) and extract fenced code blocks, list/list-item structure, blockquotes, and tables. On missing API/parser or parse failure, fall back to the existing line-based `cockpit.headings` for a reduced heading-only structural outline without throwing. Include occurrences of enabled configured markers using `cockpit.find_markers`; marker support does not depend on Tree-sitter. Entries carry kind, concise label, source line, heading level/parentage as needed to render nesting, and enough identity for source navigation. Keep parser node/range handling in this module; do not change cockpit parsing semantics.
- **Constraints / do not touch:** do not render windows or register commands; do not modify `cockpit.lua`, `init.lua`, settings, existing tests, docs, or plugin entry; do not install/configure Tree-sitter or add dependencies; do not parse inline syntax.
- **Grep anchors:** `M.headings` and `M.find_markers` in `lua/novelist/cockpit.lua`; test conventions in `tests/unit/cockpit_test.lua` and `tests/helpers.lua`.
- **Acceptance:** tests assert heading hierarchy and line positions, that heading-like lines inside fenced code are not classified as headings when Tree-sitter succeeds, recognized configured markers, representative code/list/blockquote/table entries when parser is available/mocked, and graceful heading-only fallback when parser lookup/parsing fails or buffer is plain text. No Tree-sitter parser is required for fallback tests.
- **Targeted test:** `./tests/run.sh`.

### Task 2.2.1 — Scratch outline UI and document-map command

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `lua/novelist/commands.lua`, `lua/novelist/init.lua`.
- **Must create:** none.
- **Can create:** `tests/unit/document_map_integration_test.lua` only.
- **Depends on:** `2.1.1`.
- **Spec:** Register `:NovelistDocumentMap` through the existing command lifecycle. Build entries from the current source buffer and active marker configuration, then display them in a dedicated scratch buffer in a vertical split while keeping the source visible. Render nested structure with concise labels and source line numbers. Store source buffer and source line identity for each rendered row. Enter on a valid outline row switches to the source buffer/window and jumps to its source line. Re-running the command regenerates the outline; no edit autocmd/live refresh. Indicate reduced structural parsing when Tree-sitter Markdown parsing is unavailable. Handle empty documents and invalid/stale source buffers without uncaught errors.
- **Constraints / do not touch:** do not alter core parser module or mapping behavior; do not install default keymaps; do not appropriate quickfix (used by markers); do not add dependencies; do not edit README/help.
- **Grep anchors:** `M.register`, command descriptions, and `current_buffer` in `lua/novelist/commands.lua`; setup command registration in `lua/novelist/init.lua`; outline model from Task 2.1.1.
- **Acceptance:** integration tests run the command on a sample Markdown buffer, assert a scratch outline is opened in a vertical split with expected hierarchy/line labels, verify Enter jumps to the correct source line, verify re-invocation refreshes content, and cover parser-unavailable fallback without disrupting the source. Existing command tests remain passing.
- **Targeted test:** `./tests/run.sh`.

### Task 2.3.1 — Opt-in suggested mapping preset

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `lua/novelist/keymaps.lua`, `tests/unit/keymaps_test.lua`.
- **Must edit:** `lua/novelist/init.lua`.
- **Can create:** none.
- **Depends on:** `2.2.1`.
- **Spec:** Add a single `suggested` preset, opt-in only via `keymaps = { preset = 'suggested', ... }`. Suggested global Normal-mode mappings: `<leader>nn` → `NovelistSceneNext`, `<leader>np` → `NovelistScenePrev`, `<leader>nw` → `NovelistWordCount`, `<leader>nm` → `NovelistMarkers`, `<leader>no` → `NovelistDocumentMap`. Support per-action key/mode/description override through `keymaps.mappings[action] = { lhs = ..., mode = ..., desc = ... }` and `false` disable; use `vim.keymap.set` with meaningful descriptions. On setup reconfiguration, remove only active Novelist-owned mappings that are being replaced/disabled, then install new mappings. Never overwrite a pre-existing mapping: skip and report conflicts. Ensure repeated setup does not duplicate maps and disabling the preset removes only maps still owned by Novelist. No keymap option must preserve existing no-mapping behavior.
- **Constraints / do not touch:** do not alter command implementations or docs/tests from earlier tasks; no default mappings, no buffer-local mappings, no plugin-manager adapters, no `<Plug>` API in this plan; no unrelated global map deletion.
- **Grep anchors:** `M.setup`, config merge, and `M.config` in `lua/novelist/init.lua`; existing no-default-mappings test in `tests/unit/integration_test.lua`; Neovim `vim.keymap.set` conventions in `skills/neovim-plugins/SKILL.md`.
- **Acceptance:** tests verify no maps without opt-in, suggested maps/commands/descriptions, key/mode/description overrides, false disable, pre-existing user-map preservation/conflict report, repeated setup update/disable cleanup, and that unrelated mappings remain unchanged.
- **Targeted test:** `./tests/run.sh`.

### Task 2.4.1 — Documentation and manual outline validation

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `README.md`, `doc/novelist.txt`.
- **Can create:** none.
- **Depends on:** `2.3.1`.
- **Spec:** Document `:NovelistDocumentMap`, supported outline elements, split behavior, Enter-to-source navigation, explicit refresh behavior, parser availability/fallback, and that Novelist does not install parsers. Document mapping opt-in/config API (including action IDs and `lhs`/`mode`/`desc` override shape), all suggested keys, per-action disable behavior, conflict handling, and no mappings by default. Keep README and help consistent. Add a Neovim 0.12+ manual smoke checklist for parser-present outline rendering and source jumps and parser-unavailable fallback; describe parser setup as user-owned and optional.
- **Constraints / do not touch:** no implementation/test changes; do not claim UI/parser smoke checks passed unless performed; no manager-specific examples beyond generic setup; no setup claim that configures Tree-sitter.
- **Grep anchors:** `M.setup` in `lua/novelist/init.lua`; command registration in `lua/novelist/commands.lua`; key definitions in `lua/novelist/keymaps.lua`; output/model behavior in `lua/novelist/document_map.lua`.
- **Acceptance:** README/help agree on all public options and behavior; `make test` passes; `make docs-check` resolves `:help novelist`; manual Neovim 0.12+ smoke checklist is recorded and performed for release acceptance, including split display and source jump. Parser absence must be covered by automated tests even if no parser-free runtime is available manually.
- **Targeted test:** `make test` and `make docs-check`; manual Neovim 0.12+ smoke test.

## Hazards and handoff notes

- Tree-sitter API presence does not imply the Markdown parser is installed or usable. Treat parser absence and parse errors as ordinary fallback conditions, not setup failures.
- The Markdown grammar's concrete node types/ranges must be confirmed against Neovim 0.12's installed parser; tests should avoid assuming parser availability on every machine. Use Tree-sitter heading nodes when parsing succeeds so fenced-code contents do not become false headings; the reduced fallback remains intentionally line-based.
- Tree-sitter structures may nest or overlap. Keep the outline representation deterministic and avoid duplicate rows for container and child nodes unless the renderer intentionally shows hierarchy.
- The existing marker parser is pure line-based and should remain the marker source; Tree-sitter should not be required for markers.
- Scratch UI state can outlive or refer to a deleted source buffer; validate the source buffer before jumping.
- Conflict-safe global mappings require ownership tracking across repeated setup. Never delete a mapping just because it uses a suggested key; verify it is still Novelist-owned.
- No accepted ADR is superseded. Keep the line-based cockpit parser and all existing commands stable.

## Plan review

- **Spec-axis:** all selected user requirements map to Tasks 2.1.1–2.4.1; manager adapters, inline syntax, live refresh, buffer-local mapping lifecycle, and extra formats are explicitly deferred. Mapping presets stay opt-in, and Tree-sitter remains optional with a tested reduced fallback.
- **Standards-axis:** task file scopes are explicit; waves are dependency-ordered; each task has anchors, acceptance, and targeted commands; the public command precedes its suggested mapping. UI/parser integration is separated from model extraction and mapping ownership is isolated. No task requires a shared suite to run concurrently.
- **Judgment call:** parser-supported structural nodes may overlap (e.g. list container/item). Worker should choose a deterministic non-duplicating outline representation consistent with acceptance and record it in the micro-plan; do not expand feature kinds beyond the agreed list.
- No implementation has been started as part of this planning task.
