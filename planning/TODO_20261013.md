# TODO

## Goal
Resolve the review’s duplicated test-helper and speculative marker-description findings, then validate the plugin with the dependency-free suite and a Neovim 0.12.6 smoke test.

## Tasks

### 1. Share test buffer helpers
- [x] Move the helpers duplicated by `tests/unit/settings_test.lua` and `tests/unit/integration_test.lua` into `tests/helpers.lua`, preserving their current test behavior and cleanup guarantees.
- [x] Update both test files to use the shared helpers and remove duplicate definitions.
- [x] Run `./tests/run.sh` and confirm all tests pass (22 passed, 0 failed).

### 2. Remove speculative marker-description support
- [x] Simplify `lua/novelist/cockpit.lua` marker resolution and extraction to support the documented string descriptions only; remove table-description copying/unwrapping.
- [x] Confirm tests cover default descriptions, string overrides, custom string markers, and disabled markers; add or adjust focused tests if needed.
- [x] Run `./tests/run.sh` and confirm all tests pass (22 passed, 0 failed).

### 3. Validate on Neovim 0.12.6
- [x] Run the documented smoke-test workflow with `/opt/nvim-linux-x86_64/bin/nvim` (0.12.6): load the plugin, verify Markdown prose settings, navigate headings, check word counts, and inspect filtered marker quickfix results.
- [x] Record the exact runtime version, checks performed, and outcome here; do not claim checks that were not performed.

## Notes
- Keep changes limited to `tests/helpers.lua`, the two unit test files, `lua/novelist/cockpit.lua`, and this `TODO.md`, unless a required scoped change is discovered and approved first.
- Do not modify or remove unrelated untracked `reports/`, `research_notes/`, or `.claude/` content.
- Do not commit unless separately requested.
- Validation: `/opt/nvim-linux-x86_64/bin/nvim --version` reports `NVIM v0.12.6`. A direct headless smoke workflow loaded `plugin/novelist.lua`, applied Markdown defaults (`spell`, `spelllang`, `wrap`, `linebreak`, `breakindent`, `textwidth`), navigated to next/previous headings, ran `:NovelistWordCount` (reported section 4 / document 8 for the sample), and verified `:NovelistMarkers todo` produced the expected quickfix line/text. Output: `Neovim 0.12.6 smoke checks passed`.
- The first smoke invocation used buffer-scoped option access for window-local `spell` and timed out after the assertion error; the successful rerun used Neovim's buffer/window option fallback, matching the plugin's option handling.

## Follow-up: Git ignore and tracked research files

### 1. Preserve already-separated tracked-file commits
- [x] Confirm `159ffd0` and `577793e` remain in history as separate commits; do not amend or recreate them.

### 2. Ignore only local Claude workspace data
- [x] Add `.claude/.gitignore` containing `*` so the ignore rule stays inside `.claude/`.
- [x] Verify `.claude/` contents are ignored and `reports/` and `research_notes/` remain visible to Git.
- [x] Force-add and conventionally commit `.claude/.gitignore` (its own `*` pattern may ignore the file itself): `d03e4c9`.

### 3. Track research artifacts
- [x] Add and commit `reports/` and `research_notes/` as tracked project documentation using conventional commit messages (`2fb0471`, `318c521`).
- [x] Verify the intended files are committed and no unrelated tracked changes are staged.

## Follow-up notes
- The two previously modified tracked files are already committed separately: `159ffd0` and `577793e`.
- Track all files currently under `reports/` (2 Markdown files) and `research_notes/` (6 Markdown files); track only `.claude/.gitignore` under `.claude/`.
- Leave unrelated modifications untouched and do not amend prior commits.
