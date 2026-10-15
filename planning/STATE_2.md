# State — Orchestration 2

Resume from this file and `planning/EXECUTION_PLAN_2.md`.

## Baseline checklist (before Wave 1)

- [x] Confirmed repo `/home/andrew/workspace/novelist`; working tree clean at planning intake.
- [x] Read root `AGENTS.md`, `skills/neovim-plugins/SKILL.md`, accepted ADRs 0001/0002, existing plan/master/research, and current implementation/tests/docs.
- [x] `make test` baseline: 22 passed, 0 failed.
- [x] `make docs-check` passed; generated tags removed with `make clean`.
- [x] Runtime `/usr/bin/nvim`: Neovim 0.12.5. Markdown Tree-sitter parser available locally; this does not imply parser availability in other installations.
- [x] Confirmed no manager-specific integration or parser dependency is needed for current baseline. ADRs remain accepted and are not superseded.
- [ ] Before implementation Wave 1, re-check `git status` and repeat baseline if implementation or environment has changed.

## Wave board

| Wave | Task | Status | Notes |
|---|---|---|---|
| 1 | 2.1.1 Document structure model with optional Tree-sitter | complete | report below |
| 2 | 2.2.1 Scratch outline UI and document-map command | complete | report below |
| 3 | 2.3.1 Opt-in suggested mapping preset | pending | Depends on 2.2.1 |
| 4 | 2.4.1 Documentation and manual outline validation | pending | Depends on 2.3.1 |

Maximum concurrent workers: 2. Tasks are sequential by wave; full suite and docs checks run serially at wave gates.

## Task reports

<!-- Append each worker report under its task heading; keep each report <=15 lines. -->

## 2.1.1
- Status: complete (awaiting orchestrator verification).
- Files: `lua/novelist/document_map.lua` (new, 276 lines); `tests/unit/document_map_test.lua` (new, 276 lines).
- Model: `M.build(lines, opts)` -> `{ entries, rich, reason }`; `M.kinds`; injectable `opts.get_tree`, default `M.markdown_tree` via pcall'd `get_string_parser(_, 'markdown')`. `opts.filetype ~= 'markdown'` skips Tree-sitter.
- Entries: flat line-sorted list with `kind`/`label`/`line`/`depth` (+ `level` on headings, `marker`/`value` on markers, `raw` everywhere). Containers (`document`/`section`/`list`/`pipe_table_row`/`pipe_table_header`) are not emitted -> no duplicate rows.
- Fallback: `cockpit.headings` + `cockpit.find_markers`, `rich=false`, `reason` set; parser absence/errors are ordinary, never raised.
- Test command: `./tests/run.sh` -> `Tests: 30 passed, 0 failed` (22 baseline + 8 new; includes parser-present fake-tree, fence-suppression, markers, structures, nil/raising parser, plain-text, and one guarded real-parser case).
- Deviations from approved plan: none.
- Gotchas for 2.2.1: Tree-sitter rows are 0-based and converted to 1-based `line`; render indentation from `depth`; use `rich`/`reason` to show the reduced-structure notice; markers never require Tree-sitter.

## 2.2.1
- Status: complete (awaiting orchestrator verification).
- Files: `lua/novelist/commands.lua` (+134 lines); `tests/unit/document_map_integration_test.lua` (new, 4 tests). `init.lua` unchanged.
- Command: `:NovelistDocumentMap` registered in `M.register`; opens/reuses one named scratch buffer `novelist://document-map` (`nofile`, `bufhidden=wipe`) in a vertical split, source kept visible.
- Render: `indent + label + '  [line]'` rows from `document_map.build`; non-jumpable reduced-structure notice (`rich=false`) and empty-document placeholder; row->{bufnr,line} targets.
- Interaction: buffer-local `<CR>` (`buf = bufnr`, with `desc`) jumps to the source buffer/window/line, pcall-guarded; stale source notifies; self-run from the outline is guarded.
- Refresh: re-invocation rebuilds from current lines + markers; no edit autocmd/live tracking.
- Tests: `./tests/run.sh` -> `Tests: 34 passed, 0 failed` (22 baseline + 8 document_map + 4 integration); parser-present rich test guarded by a parser probe.
- Deviation: verification retry changed `buffer = bufnr` to `buf = bufnr` in the `<CR>` map (0.12 spelling; both accepted on 0.12.5).
- Gotchas for 2.3.1: no default global maps; the only new keymap is buffer-local to the plugin-owned outline buffer.
