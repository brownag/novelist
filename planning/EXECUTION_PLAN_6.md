# Execution Plan 6 — Phase 1 Neovim 0.12+ manual smoke gate (G1)

## Goal & Scope

### Goal

Pass the Neovim 0.12+ smoke gate for Phase 1 (Integrations and Interaction) on the current HEAD, and record the outcome. This closes the only remaining gate between Phase 1 and later roadmap phases. No plugin, test, or documentation changes are made by this plan.

### In scope
- Run all 17 steps of README "Manual smoke test for Neovim 0.12+" against the system runtime `/usr/bin/nvim` (0.12.6) and Vale 3.24.0 (`/usr/bin/vale`).
- Scripted headless execution with explicit assertions for every step.
- A short visual confirmation by the user for layout and cursor behavior (README steps 10–12 and 15).
- Record every step's result, exact commands, and output excerpts in `planning/STATE_6.md`.
- Commit the record on branch `test/vale-no-context-argv`.

### Out of scope / deferred
- Any code, test, README, or vimdoc change. A failed step is recorded and the gate stays open; a fix needs a separate, user-approved task.
- Installing or relocating Neovim or Vale. The `/opt/nvim-linux-x86_64/bin/nvim` path in GOALS.md is missing; this plan uses `/usr/bin/nvim` by user decision.
- Changes to the user's Vale configuration or repo `.vale.ini`. Step 14 fixtures live in an OS-temp directory only.
- Merging to `main`.
- Writing the Phase 2 (Writing Assistance) scoping work (G5), and G2/G3/G6 items.
- Editing `planning/STATE_5.md`. The gate record lives in `planning/STATE_6.md` because each orchestration owns its own state file.

### Verbatim constraints and user statements
- GOALS G1 exit criteria: "all 17 steps in README 'Manual smoke test for Neovim 0.12+' pass on Neovim 0.12.6, with the outcome recorded."
- README: "Manual validation on Neovim 0.12+ remains a release gate unless it is actually run on that runtime."
- User decision (2026-11-01): "Scripted headless run, plus a short visual check (Recommended)."
- User decision: "System nvim 0.12.6 + Vale 3.24.0 (Recommended)."
- User decision: "Record and stop (Recommended)" — on any failure, record it with output and stop; no code fixes in this plan.
- User decision: "Commit on current branch (Recommended)" — one docs commit on `test/vale-no-context-argv`; `doc/tags` stays untracked.
- Repo guidance: "Keep user-facing behavior ... documented"; no default keymaps (ADR 0002); no required dependencies (ADR 0001).

## Decision log (2026-11-01)

1. **Gate method:** scripted headless run of all 17 steps, plus a user visual check for steps 10–12 and 15. Headless checks use window/buffer/quickfix/loclist state; they do not prove on-screen appearance.
2. **Runtime:** `/usr/bin/nvim` 0.12.6 and `/usr/bin/vale` 3.24.0. The plan's earlier Vale reference (3.20.0) is superseded for this gate only.
3. **Failure policy:** record and stop. The first failing step is recorded with exact output; later steps are marked `not run`. Gate stays open. No repo edits.
4. **Record location:** `planning/STATE_6.md`, not `STATE_5.md`. Orchestration numbering is preserved; prior state files are not rewritten. GOALS.md's exit-criteria text names STATE_5.md, so the file reference in GOALS.md should be updated when the gate closes.
5. **Commit:** one `docs(planning)` commit on `test/vale-no-context-argv` after the gate finishes, containing `planning/STATE_6.md`, `planning/tasks/6.1.1.todo.md`, and any `planning/` artifacts this plan created. `doc/tags` is not committed.
6. **Architecture:** no ADR is superseded or proposed. Work complies with ADR 0001 and ADR 0002.

## Reconnaissance

- Repo: `/home/andrew/workspace/novelist`; branch `test/vale-no-context-argv` at `bef5e8f`; `main` at `a28dec2`. Working tree clean except untracked `doc/tags` and `planning/GOALS.md`.
- Runtime: `nvim` 0.12.6 at `/usr/bin/nvim`. `/opt/nvim-linux-x86_64/bin/nvim` does not exist.
- Vale: 3.24.0 at `/usr/bin/vale`.
- Markdown parsers present: `~/.local/share/nvim/site/parser/markdown.so` and `markdown_inline.so`. Document-map Tree-sitter path is testable.
- Baseline suite: `make test` → 49 passed, 0 failed (last run this session).
- Repo files: `plugin/novelist.lua` (1 line); `lua/novelist/init.lua` (95); `lua/novelist/commands.lua` (388); `lua/novelist/keymaps.lua` (174); `lua/novelist/document_map.lua` (276); `lua/novelist/vale.lua` (95); `lua/novelist/cockpit.lua` (217); `lua/novelist/settings.lua` (106). README is 278+ lines; the smoke section starts at line 263.
- Commands under test: `:NovelistWordCount`, `:NovelistSceneNext`, `:NovelistScenePrev`, `:NovelistMarkers` (with optional filter), `:NovelistDocumentMap`, `:NovelistVale`, and `keymaps = { preset = 'suggested' }`.
- Opt-out switch: `vim.b.novelist_disable`.

## Wave table

| Wave | Tasks | Purpose | Dependencies |
|---|---|---|---|
| 1 | `6.1.1` | Run all 17 smoke steps, record results | — |

One task, one wave. The steps are sequential and share one Neovim session fixture, so parallel workers would collide.

## Task specifications

### Task 6.1.1 — Run the Neovim 0.12+ smoke gate and record results

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `planning/STATE_6.md` (task report section only), `planning/tasks/6.1.1.todo.md`.
- **Can create:** OS-temp-only fixtures and scripts under a `mktemp -d` directory, removed at the end. Nothing else.
- **Depends on:** none.
- **Spec:**
  1. Confirm `/usr/bin/nvim --version` reports `NVIM v0.12.6` and `vale --version` reports 3.24.0. Record both.
  2. Make a temp fixture project with a `.vale.ini` and a style that flags a known word at `level: error`. Use the README sample Markdown (the fenced block under step 5 of the smoke section, starting after README.md line 263) as the buffer content.
  3. Run each README step 1–17 as a headless `nvim --headless -u NONE --cmd "set rtp+=<repo>"` script with assertions:
     - Steps 1–4: `:version` shows 0.12.6; `filetype=markdown`; `spell`, `spelllang`, `wrap`, `linebreak`, `breakindent`, `textwidth` match `settings.defaults` (read values from `lua/novelist/settings.lua` by grep, not by hand).
     - Steps 5–6: buffer contents match the sample; `:NovelistWordCount` output reports section and document counts (record the numbers).
     - Step 7: `:NovelistSceneNext` and `:NovelistScenePrev` move the cursor between headings from two different lines.
     - Step 8: `:NovelistMarkers` fills quickfix with the marker lines; `:NovelistMarkers todo` filters to the `@todo` line.
     - Step 9: with `vim.b.novelist_disable = true` set before FileType, prose settings are not applied.
     - Step 10: `:NovelistDocumentMap` opens a vertical split; record window count and the heading rows.
     - Step 11: from the outline, `<CR>` on rows moves the source cursor to the matching line; editing the source leaves the outline unchanged until re-run; re-run refreshes it.
     - Step 12: with no Markdown parser (`vim.treesitter.get_string_parser` disabled or a plain-text buffer), the headings-only outline opens with the reduced-structure notice.
     - Step 13: `keymaps = { preset = 'suggested' }` creates the five `<leader>n?` mappings; one `lhs`/`mode`/`desc` override and one `false` disable behave as documented; plain `setup()` maps none. Confirm via `vim.api.nvim_get_keymap` / `maparg`.
     - Step 14: Vale project is the temp fixture; the repo's `.vale.ini` is never read or written.
     - Step 15: run `:NovelistVale` on a flagged draft; loclist opens with the finding; global quickfix unchanged.
     - Step 16: edit the buffer without saving; `:NovelistVale` reflects the unsaved text.
     - Step 17: `:NovelistVale` on a clean buffer reports no findings and does not open an empty loclist.
  4. Stop at the first failing step. Record that step's exact command, expected, and observed output; mark later steps `not run`.
  5. Visual check (user): after the scripted run, hand the user the exact nvim commands for steps 10–12 and 15 and ask them to confirm. Do not mark those steps `pass` until the user confirms; record `scripted pass, visual pending` in the meantime.
  6. Remove the temp directory and confirm it is gone.
  7. Run `make test` and `git diff --check`; both must pass.
- **Constraints / do not touch:** No edits to `lua/`, `plugin/`, `tests/`, `README.md`, `doc/`, `Makefile`, `docs/`, or `planning/` files other than those listed. Do not commit `doc/tags`. Do not modify the user's Vale configuration or any `.vale.ini` outside the temp directory. No `sudo`. No package installs.
- **Grep anchors:** `README.md` "Manual smoke test for Neovim 0.12+" (~line 263); `lua/novelist/settings.lua` `defaults`; `lua/novelist/commands.lua` `nvim_create_user_command` (~lines 357–382); `lua/novelist/keymaps.lua` `suggested` preset (~line 64); `lua/novelist/vale.lua` `build_argv`.
- **Acceptance:** `planning/STATE_6.md` has a `## 6.1.1` report with one line per step 1–17 (`pass` / `scripted pass, visual pending` / `fail` / `not run`), exact runtime versions, and `make test` result. The temp directory is removed.
- **Targeted test:** the scripted per-step runs above; `make test`.

## Hazards and handoff notes

- The gate measures headless state. Layout and cursor visibility are confirmed only by the user's visual check; the report must say so.
- The first failing step stops execution. Do not "fix and retry" inside the task.
- The Vale fixture must be in the OS temp directory. Never write `.vale.ini` or styles into the repo.
- `doc/tags` may exist from `make docs-check`; leave it untracked.
- Do not claim a step passed that was not run.

## Plan review

- **Spec axis:** Every G1 exit criterion maps to 6.1.1 steps 1–17; the visual check maps to step 5; the user's failure policy maps to step 4; the commit decision maps to the commit plan in the decision log. No Phase 2+ work is pulled in.
- **Standards axis:** One task, one wave; files in scope are explicit; acceptance is checkable from `STATE_6.md` and `make test`; anchors replace whole-file reads. The one judgment call is the 17-step scope for a single worker; it is listed in the approval message.
