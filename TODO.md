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
