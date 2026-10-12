# Execution Plan 1 — Novelist prose settings and revision cockpit

## Goal & Scope

### Goal

Build `novelist`, a standalone Lua Neovim plugin for prose writers, combining a small prose-settings preset with a narrative revision cockpit. The first version supports Markdown and plain-text buffers, uses Neovim 0.12+ as its target, has no required third-party dependencies, and provides automatic prose settings, heading-based scene/section navigation, section and total word counts, and configurable `@who`, `@what`, `@where`, `@when`, `@why`, and `@todo` markers.

### In scope

- Establish the repository's plugin layout and dependency-free headless test harness.
- Apply configurable prose-friendly local options to Markdown and plain-text buffers, with a global configuration opt-out and per-buffer opt-out.
- Parse Markdown ATX headings and marker lines from buffer text without requiring Tree-sitter.
- Provide named commands for previous/next heading navigation, section/document word counts, and marker lookup; install no default keymaps.
- Document installation, setup/configuration, commands, marker definitions, and known MVP limits.

### Out of scope / deferred

- Vale, LTeX/LanguageTool, grammar, or style-linter integration.
- Manuscript compilation, export, or submission-format pipeline.
- Org/Neorg and non-Markdown/non-plain-text filetype support.
- Story-bible/vault features, backlinks, timeline consistency analysis, or automatic narrative interpretation.
- Tree-sitter or other required dependencies; plugin-manager-specific integration; default keymaps.
- Building focus-mode or Markdown-rendering features; users can combine existing plugins identified in `docs/research/neovim-prose-narrative-plugins.md`.

### Verbatim constraints and decisions

- User: “revision cockpit and prose settings plugin. the other options will come later”
- User agreed to Markdown and plain text first; Org/Neorg deferred.
- User agreed to heading-based section navigation, section/total word counts, and configurable story markers.
- User agreed settings apply automatically to Markdown/plain-text buffers, spell language is configurable, there is an opt-out, and wrapping is visual rather than hard-wrapping saved text.
- User agreed to named commands and no default keymaps.
- User agreed on standalone Lua, no required third-party dependencies, and simple buffer-line parsing rather than requiring Tree-sitter.
- User: “yes, we can go more rcent if needed i have Neovim 0.12+” — target Neovim 0.12+; do not add compatibility work for older versions.
- User agreed `novelist` is the plugin name and Lua module namespace.
- User agreed to dependency-free headless tests on the available 0.11.6 where possible, with 0.12+ validation outstanding until available.
- User agreed to a maximum of two concurrent workers.
- User agreed acceptance includes automated headless tests and a manual smoke test in Neovim 0.12+.
- User agreed to use the cheapest capable worker model, escalating only at the orchestration skill's defined limits.
- User: “I wonder if we did who/what/where/when/why + todo” — these are the agreed default marker names, with the definitions below.
- User confirmed the repository has now been initialized as Git.

### Marker definitions (MVP defaults)

Markers are standalone Markdown/plain-text metadata lines of the form `@name: value`. They are plain text; the plugin does not infer story meaning.

| Marker | Default description / intended meaning | Example |
|---|---|---|
| `@who` | Viewpoint character first, followed by other important people in the scene. | `@who: Mira (POV), Ivo` |
| `@what` | Central event, conflict, or change in the scene. | `@what: Mira discovers the forged letter` |
| `@where` | Scene location. | `@where: North bridge, east tower` |
| `@when` | Placement in the story chronology. | `@when: Winter, year 12` |
| `@why` | Why the scene matters: its purpose, stakes, or cause in the story. | `@why: Forces Mira to choose whether to trust Ivo` |
| `@todo` | Unresolved drafting/revision task; may appear anywhere and repeat. | `@todo: Seed the letter's wax seal earlier` |

`@why` means scene purpose/stakes by default; users may put character motivation in its value when useful. Marker defaults/descriptions must be easy to extend, rename, override, or disable through Lua configuration; marker values remain arbitrary text.

## Decision log

All decisions below were confirmed on 2026-10-11.

1. **Product focus:** revision cockpit plus prose settings; defer Vale and manuscript pipeline.
2. **Formats:** Markdown and plain text only for first release.
3. **Cockpit MVP:** heading-based navigation, section/document counts, configurable markers.
4. **Settings:** automatically enable for supported buffers; configurable spell language; visual wrapping; no inserted hard wraps; opt-out supported.
5. **UX:** user commands only; no default mappings.
6. **Architecture:** Lua, no required external dependencies, plain buffer-line parsing.
7. **Runtime:** Neovim 0.12+ target; use the available 0.11.6 for compatible tests but do not claim 0.12 validation from it.
8. **Namespace:** `novelist`.
9. **Validation:** dependency-free headless tests plus manual Neovim 0.12+ smoke test.
10. **Parallelism/model:** at most two workers; cheapest capable worker model with the defined escalation ladder.
11. **Git:** repository initialized by user before plan execution.

## Repository reconnaissance

- Repo: `/home/andrew/workspace/novelist`; Git branch `master`, initial commit `1fd0f27` (`Initial research`).
- Existing tracked content at planning time: `docs/research/neovim-prose-narrative-plugins.md` only.
- No `AGENTS.md`, `CONTRIBUTING`, existing source tree, test runner, README, Makefile, or prior planning artifacts found.
- Available runtime: `/usr/bin/nvim`, Neovim 0.11.6; this is below the agreed 0.12+ target. Automated checks should avoid APIs unavailable in 0.11.6 where practical, but final smoke validation must be repeated on 0.12+.
- No existing code is available to pattern-match. Primary technical reference: `docs/research/neovim-prose-narrative-plugins.md`; Neovim runtime docs linked there describe Lua plugin layout, filetype loading, spell, and prose display options.
- No baseline test suite exists. Record the first headless harness run as the baseline before feature tasks.
- Git workflow is available; each completed task is expected to receive its own conventional commit during orchestration.

## Conventions and implementation contract

- Plugin source layout: `plugin/novelist.lua` for runtime entry; `lua/novelist/` for modules. Public setup is `require('novelist').setup(opts)`.
- `setup()` is safe to call more than once: reconfigure behavior without duplicate autocmds/commands.
- Supported buffer filetypes: `markdown` and `text` by default; allow configuration to replace/extend this list.
- Prose defaults: local `spell=true`, configurable `spelllang` defaulting to `{ 'en_us' }`, `wrap=true`, `linebreak=true`, `breakindent=true`, `textwidth=0`. Do not globally alter options or insert line breaks into buffer content.
- Configuration includes a prose enable/disable option and buffer-local opt-out via `vim.b.novelist_disable = true`. Configuration shape should be small and documented; proposed shape: `prose = { enabled, filetypes, spelllang }`, `markers = { name = description }`.
- Marker map starts with six agreed defaults. Merge user marker entries over defaults; `false` removes a default/custom entry. Treat descriptions as UI/help text only. Recognize only standalone lines matching `@name: value` with optional leading whitespace; ignore unknown/disabled marker names. Do not parse arbitrary inline `@` mentions.
- A scene/section is defined by an ATX Markdown heading (`#` through `######` followed by whitespace) at line start, optionally preceded by indentation. A section spans its heading through the line before the next heading of any level. For headingless text, use one implicit whole-document section.
- Navigation moves the cursor to the next/previous heading; from a headingless document, report that no section heading exists without moving the cursor.
- Word-count MVP: count whitespace-delimited non-empty tokens in section/document body lines, excluding standalone recognized marker lines; include section heading text after stripping the leading Markdown heading prefix. This is intentionally simple, not a full Markdown or linguistic tokenizer.
- Marker lookup lists matching occurrences in the quickfix list with filename, line, and marker text. `:NovelistMarkers` lists all enabled markers; optional marker-name argument filters. The command opens the quickfix window only when results exist.
- User commands: `:NovelistSceneNext`, `:NovelistScenePrev`, `:NovelistWordCount`, `:NovelistMarkers [name]`. No default keymaps.
- Test harness must not require Plenary or any other plugin. One documented/scriptable command should run it headlessly.

## Wave table

| Wave | Tasks | Purpose | Dependencies |
|---|---|---|---|
| 1 | `1.1` | Establish project/test foundation | — |
| 2 | `2.1`, `2.2` | Implement prose settings and cockpit parsing as independent modules | Wave 1 |
| 3 | `3.1` | Integrate setup, autocmds, and user commands | Wave 2 |
| 4 | `4.1` | Finish user and help documentation; verify release acceptance | Wave 3 |

Maximum concurrency: 2 workers. Files-in-scope within each wave are disjoint.

## Task specifications

### Task 1.1 — Project foundation and headless test harness

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `tests/run.lua`, `tests/helpers.lua`, `tests/run.sh`.
- **Can create:** `tests/unit/` test files only if needed for a harness self-test; no production modules in this task.
- **Depends on:** none.
- **Spec:** Create a tiny dependency-free Lua test harness runnable through installed Neovim headless mode. Provide shared assertions/test registration, deterministic test execution and nonzero process exit on failures. `tests/run.sh` should locate/run `nvim` and clearly report a missing executable. The runner must discover and execute `tests/unit/*_test.lua` files deterministically, including zero tests at initial scaffold time. Keep test APIs stable for later module tasks.
- **Constraints / do not touch:** do not add a third-party test dependency; do not add production plugin code; do not edit the research note; do not modify unrelated Git/config files.
- **Grep anchors:** none; repository has no implementation files.
- **Acceptance:** `tests/run.sh` exits zero on an empty suite and prints a concise pass summary; a deliberate failing assertion in a temporary/untracked check proves nonzero exit, then remove the temporary check. `nvim --version` is informational only.
- **Targeted test:** `./tests/run.sh`.

### Task 2.1 — Prose settings module

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `lua/novelist/settings.lua`, `tests/unit/settings_test.lua`.
- **Can create:** none.
- **Depends on:** `1.1`.
- **Spec:** Implement a small module that applies the prose preset to a supplied valid buffer and settings. Defaults are `spell=true`, `spelllang={ 'en_us' }`, `wrap=true`, `linebreak=true`, `breakindent=true`, and `textwidth=0`. Use buffer-local options only; honor global `enabled`, supported `filetypes`, and `vim.b.novelist_disable`. Do not create the autocmd or public configuration entry point; integration owns lifecycle. Keep settings configurable and avoid mutating global options or buffer text.
- **Constraints / do not touch:** do not touch shared test harness, plugin entry, public setup, command files, docs, or cockpit module. No dependencies.
- **Grep anchors:** test helpers from `tests/helpers.lua`; harness contract from `tests/run.lua`.
- **Acceptance:** tests assert defaults apply locally, spell language override works, disabled config skips settings, buffer opt-out skips settings, and unrelated/global options and buffer contents remain unchanged.
- **Targeted test:** `./tests/run.sh`.

### Task 2.2 — Heading, count, and marker parsing module

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `lua/novelist/cockpit.lua`, `tests/unit/cockpit_test.lua`.
- **Can create:** none.
- **Depends on:** `1.1`.
- **Spec:** Implement pure functions over arrays of buffer lines for Markdown ATX heading sections, next/previous heading lookup, section/document word counts, and configured marker occurrence extraction. Follow the exact parsing/counting contract above. Default marker metadata (names/descriptions) must be exported in a configuration-friendly form; user-supplied entries override defaults and `false` disables a marker. Recognize only standalone `@name: value` lines; preserve occurrence line numbers and raw marker text. The functions should not read or mutate editor state.
- **Constraints / do not touch:** do not implement autocmds, UI, commands, or setup; do not touch test harness, settings module, docs, or unrelated files. No Tree-sitter or external deps.
- **Grep anchors:** test helpers from `tests/helpers.lua`; harness contract from `tests/run.lua`.
- **Acceptance:** unit tests cover heading hierarchy/boundaries, implicit headingless section, next/previous navigation results, heading-prefix removal from counts, marker-line exclusion from counts, configured/disabled/unknown markers, multiple TODOs, and stable line numbers.
- **Targeted test:** `./tests/run.sh`.

### Task 3.1 — Public setup, settings lifecycle, and commands

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `plugin/novelist.lua`, `lua/novelist/init.lua`, `lua/novelist/commands.lua`, `tests/unit/integration_test.lua`.
- **Can create:** none.
- **Depends on:** `2.1`, `2.2`.
- **Spec:** Connect the settings and cockpit modules behind `require('novelist').setup(opts)`. Initialize defaults from the plugin runtime entry, permit later user setup calls to update config without duplicate registrations, and apply settings on supported `FileType` events. Register documented user commands: `NovelistSceneNext`, `NovelistScenePrev`, `NovelistWordCount`, and `NovelistMarkers [name]`. Navigation moves to next/previous ATX heading. Word count reports current section and document totals using `vim.notify` (or an equivalent built-in message mechanism). Marker listing populates quickfix entries and opens the quickfix window only when there are matches. No default mappings. Handle invalid buffer/no-heading/no-match cases without throwing uncaught errors.
- **Constraints / do not touch:** do not modify settings or cockpit core modules; do not add third-party dependencies; do not modify docs or test runner.
- **Grep anchors:** `M.apply` in `lua/novelist/settings.lua`; pure API/defaults in `lua/novelist/cockpit.lua`; unit-test helper contract.
- **Acceptance:** headless integration tests verify setup can be repeated, settings apply on Markdown/text FileType, unsupported filetypes are unaffected, per-buffer opt-out works, commands register and operate against sample buffers, quickfix entries have correct filename/line/text, and no keymaps are installed.
- **Targeted test:** `./tests/run.sh`.

### Task 4.1 — User documentation and release-facing validation

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `README.md`, `doc/novelist.txt`.
- **Can create:** none.
- **Depends on:** `3.1`.
- **Spec:** Document install with a generic plugin manager, Neovim 0.12+ requirement, `setup()` configuration examples, defaults/opt-outs, supported filetypes, all four commands, all six marker definitions and syntax, word-count limitations, and a short manual smoke-test recipe. Keep README and `:help novelist` consistent. Mention no automatic narrative inference and no grammar/style checking.
- **Constraints / do not touch:** do not change implementation or tests; no claims of successful Neovim 0.12+ validation unless actually run under 0.12+.
- **Grep anchors:** public API/command definitions in `lua/novelist/init.lua`, `lua/novelist/commands.lua`; marker/default behavior in `lua/novelist/cockpit.lua`; settings in `lua/novelist/settings.lua`.
- **Acceptance:** README and help cover every public command/configuration option; names/defaults/examples match code; `:help novelist` resolves from plugin runtime path; dependency-free headless suite passes.
- **Targeted test:** `./tests/run.sh`; manual smoke test on Neovim 0.12+ remains required release gate.

## Hazards / handoff notes

- Current environment is Neovim 0.11.6, not the target 0.12+. Do not label 0.12 acceptance as passed without a separate run on 0.12+.
- Word counts intentionally use whitespace-delimited tokens; Markdown syntax beyond heading prefix is not parsed or normalized.
- Section detection treats any ATX heading as a section boundary; it does not infer semantic chapter/scene levels.
- `@why` and other values remain writer-authored free text, not machine-interpreted story facts.
- Repo was empty apart from research at planning time; workers must create the stated paths and keep task file scopes exact.

## Plan review

- **Spec-axis pass:** every agreed user requirement is represented in goal/scope, decisions, marker definitions, implementation contract, and tasks; deferred topics are explicitly out of scope.
- **Standards-axis pass:** four waves are dependency ordered; parallel Wave 2 tasks have disjoint source/test files; each task has explicit files, anchors, acceptance and test command; no task exceeds 12 micro-plan steps; integration owns shared lifecycle/commands.
- No code has been implemented as part of this planning step.
