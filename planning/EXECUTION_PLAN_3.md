# Execution Plan 3 — Optional Vale writing-assistance integration

## Goal & Scope

### Goal

Add an explicitly invoked, optional Vale grammar/style check for Novelist's existing Markdown and plain-text buffers. `:NovelistVale` should check the buffer's current contents, including unsaved edits, invoke Vale asynchronously using its normal project/user configuration, and show findings in the invoking window's location list without disturbing the global quickfix list. Vale remains an external, user-installed tool; the default executable is `vale` and users may override its path. This plan does not change Novelist's standalone behavior when Vale is absent.

### In scope

- A Vale invocation/output module, asynchronous execution, stdin handling for current unsaved text, JSON diagnostic parsing, and graceful process/parse errors.
- `:NovelistVale` integration for the existing `markdown` and `text` filetypes, a `vale.executable` setup option, and invoking-window location-list reporting.
- Automated coverage using a fake executable, documentation updates to README and vimdoc, and a Neovim 0.12+ manual smoke checklist/run where a Vale configuration is available.

### Out of scope / deferred

- Automatic/background-on-edit linting, other checkers (including LTeX/LanguageTool), new filetype/format support, bundled Vale styles/configuration, installation or configuration of Vale, manager-specific adapters/examples, keymaps, and automatic narrative interpretation.
- Any required external tool or Neovim plugin dependency; Vale is optional and only needed when the user invokes the command.
- Changing marker semantics or inferring story meaning from writer-authored text.

### Verbatim constraints and user statements

- Master plan: “Keep the plugin standalone Lua, with no required third-party dependencies.”
- Master plan: “Markdown and plain text are the initial supported formats. Org/Neorg and other filetypes are deferred unless explicitly brought into a future plan.”
- Master plan: “Descriptions are display metadata and values remain writer-authored text.”
- User decision: grammar/style integration is in scope; automatic narrative interpretation remains separate and optional.
- User decision: focus on Vale, not a generic multi-checker abstraction.
- User decision: use an explicit `:NovelistVale` command, report findings through a list, and do not run automatically while typing.
- User decision: check current buffer contents including unsaved edits.
- User decision: Vale uses its normal project/user configuration; Novelist neither creates nor modifies Vale configuration.
- User decision: default executable is `vale`, with a setup override; report a clear launch error.
- User decision: use the invoking window's location list, not the global quickfix list.
- User decision: support existing `markdown` and `text` filetypes only.
- User decision: invoke asynchronously.
- User decision: setup shape is top-level `vale = { executable = 'vale' }`; no `enabled` option is needed because invocation is explicit.
- User decision: open location list when findings exist; notify when none; errors must not replace the location list.
- User decision: capture the invoking window and buffer; async results update/open only that window's location list. If that window has closed or no longer displays the source buffer, do not mutate another window's list; report that results could not be displayed there.
- User decision: automate tests with a fake executable for findings/no-findings/process failures; manual Neovim 0.12+ validation with configured Vale is a release check when available.

## Decision log (2026-10-15)

1. **Scope:** Optional grammar/style checker integration only; Vale is the first target. Narrative interpretation and other checkers are deferred.
2. **Invocation:** Explicit `:NovelistVale`; no automatic linting.
3. **Buffer semantics:** Lint live buffer text, including unsaved edits. Do not require a save first.
4. **Configuration ownership:** Use Vale's normal configuration; Novelist does not install Vale, bundle styles, or write Vale config.
5. **Executable:** `vale` by default, override with `vale.executable`; missing/unlaunchable executable produces a clear error.
6. **Diagnostics:** Use the invoking window's location list; preserve global quickfix. Capture invoking window and source buffer before launch. Update/open only that window's loclist if it remains valid and displays the captured buffer; otherwise do not mutate another window's loclist and notify that results could not be displayed. Open location list only if findings exist; notify on zero findings. Failures leave the existing location list intact.
7. **Formats:** Only existing `markdown` and `text` filetypes.
8. **Execution:** Asynchronous process invocation.
9. **Setup shape:** Top-level `vale = { executable = 'vale' }`, with no enable flag.
10. **Acceptance:** Automated fake-executable tests cover findings, empty results and process failures. Manual Neovim 0.12+ smoke validation with user-configured Vale is expected when available; do not claim it passed unless performed.
11. **Architecture:** No ADR is superseded. The implementation must comply with ADR 0001 (no required dependencies, parsing/process module separate from Neovim command integration) and ADR 0002 (named command, no default mappings).
12. **Ordering/parallelism:** CLI adapter/model precedes command integration; docs follow implementation. Maximum two concurrent workers remains the repository's established limit; these tasks are sequential by wave.

## Reconnaissance

- Repo `/home/andrew/workspace/novelist`; `git status --short` was empty before planning. `make test`: 38 passed, 0 failed. `make docs-check`: passed; generated tags removed with `make clean`.
- Runtime `/usr/bin/nvim` is Neovim 0.12.5. Vale is locally available as `/usr/bin/vale`, version 3.20.0, but the repo has no `.vale.ini`; `vale ls-config` reports no config. Thus automated tests must not depend on the local binary/config, and manual live checking may require user configuration.
- Canonical commands: `make test`, `make docs-check`, `make clean`; `tests/run.sh` invokes Neovim headless. No shared network/server resources; run full suite serially at wave gates.
- Conventions: root `AGENTS.md`; `skills/neovim-plugins/SKILL.md` recommends `vim.system(cmd, opts, on_exit)` for external processes and scheduling editor API work out of fast callbacks; tests use the project harness and fake/controlled environment; README and vimdoc must remain aligned.
- Entry points/sizes: `plugin/novelist.lua` (1 line), `lua/novelist/init.lua` (94), `commands.lua` (283), `settings.lua` (106), `cockpit.lua` (217), `keymaps.lua` (174), `document_map.lua` (276); tests include `integration_test.lua` (198), `helpers.lua` (145); README (236), vimdoc (352).
- Integration pattern: `init.lua` owns deep-ish config merging, FileType setup, command registration and keymap setup. `commands.lua` owns named commands, current buffer access, notifications, quickfix marker results, and document-map UI. Reference `:NovelistMarkers` for list item construction, and integration tests for `setup()` and public command behavior. `vim.fn.setloclist` / `vim.fn.getloclist` will be needed for per-window results.
- Vale CLI local help confirms `--output=JSON`, stdin support, `--ext`, and `--path`; Vale's JSON output and exit-code behavior must be verified against a controlled invocation during implementation. Vale may return a nonzero exit when lint findings are present, which is not necessarily a process failure.
- Accepted ADRs 0001/0002 remain in force. This work is optional external-tool integration, not a dependency; named-command-only behavior and no default keymaps remain unchanged.
- Research/API references: [Vale CLI documentation](https://vale.sh/docs/vale-cli/), [Vale configuration](https://vale.sh/docs/topics/config/), [Neovim `vim.system()`](https://neovim.io/doc/user/lua.html#vim.system()), [Neovim location lists](https://neovim.io/doc/user/quickfix.html#location-list).

## Wave table

| Wave | Tasks | Purpose | Dependencies |
|---|---|---|---|
| 1 | `3.1.1` | Build/test the Vale stdin, async process, and JSON diagnostic adapter | — |
| 2 | `3.2.1` | Add setup option and `:NovelistVale` location-list command | 3.1.1 |
| 3 | `3.3.1` | Document Vale setup, command behavior, limits, and smoke workflow | 3.2.1 |
| 4 | `3.4.1` | Correct stdin invocation for real Vale and verify findings end to end | 3.3.1 |

All waves are sequential. Within-wave file scopes are disjoint (single task per wave). Maximum concurrency: 2.

## Task specifications

### Task 3.1.1 — Vale process and diagnostic adapter

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must create:** `lua/novelist/vale.lua`, `tests/unit/vale_test.lua`.
- **Can create:** temporary fake executables and fixture data under the OS temp directory only; do not leave repository artifacts.
- **Depends on:** none.
- **Spec:** Implement the isolated process/JSON adapter for Vale. Accept the executable, current buffer text, supported filetype/path context, and completion callback; invoke Vale asynchronously with JSON output and stdin association suitable to the current file (including unsaved contents). Parse Vale JSON into stable diagnostic records (line, column where available, severity, message, rule/check, source path) without editor UI calls. Distinguish successful findings (including Vale's documented/verified findings exit status) from launch/process errors and malformed output. Preserve stdout/stderr and useful error context for the integration task. Do not call `nvim_setloclist` or notify from this module. Keep it small and dependency-free.
- **Constraints / do not touch:** do not edit `commands.lua`, `init.lua`, README/help, or existing tests; do not add dependencies or shell-interpolate user paths; do not invoke Vale synchronously; do not write config or styles.
- **Grep anchors:** external-process conventions in `skills/neovim-plugins/SKILL.md`; test harness/fake process patterns in `tests/helpers.lua` and `tests/unit/`; CLI help confirmed options `--output=JSON`, `--ext`, `--path`.
- **Acceptance:** `./tests/run.sh` tests JSON findings with accurate line/column/severity/message, empty findings, unsaved input passed to stdin, extension/path context, findings exit status, non-findings process failure, missing executable/launch failure, and malformed JSON. Tests must use a fake executable or deterministic process seam, never require installed Vale or `.vale.ini`.
- **Targeted test:** `./tests/run.sh`.

### Task 3.2.1 — Explicit command and location-list integration

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `lua/novelist/init.lua`, `lua/novelist/commands.lua`, `tests/unit/integration_test.lua`.
- **Can create:** none.
- **Depends on:** `3.1.1`.
- **Spec:** Add default config `vale = { executable = 'vale' }`, merged consistently with current `setup()` behavior. Register `:NovelistVale` as an explicit command. Reject/notify for unsupported filetypes (only `markdown` and `text` are supported), capture current buffer, invoking window, lines and filename before launching, and use the Task 3.1.1 adapter asynchronously. On completion, schedule Neovim API work safely. Update/open the location list only in the captured window if it remains valid and still displays the captured buffer; otherwise leave every other window's list untouched and notify that findings could not be displayed. Ignore deleted source buffers and stale buffer identity. Convert diagnostics into location-list items for the captured source buffer; open that location list only when findings exist. Notify when no findings exist. Missing executable, process failure, or invalid output should report a clear error and leave the existing location list untouched. Never change global quickfix. Use `vale.executable` override without adding an `enabled` setting. Add integration tests for command registration, supported/unsupported buffers, unsaved contents, success/findings, empty result, location list vs quickfix isolation, executable override, failures preserving the previous location list, and window switches/closure ensuring results never replace an unrelated window's location list.
- **Constraints / do not touch:** do not change `vale.lua` or its tests; do not modify existing commands' semantics; no automatic linting/autocmds/keymaps; no other filetypes, config writing, styles, or dependencies.
- **Grep anchors:** `M.setup` / `default_config` in `lua/novelist/init.lua`; `M.register`, `current_buffer`, `notify`, and marker list construction in `lua/novelist/commands.lua`; test setup helper and marker command in `tests/unit/integration_test.lua`; adapter contract from Task 3.1.1.
- **Acceptance:** integration tests verify `:NovelistVale` behavior, current unsaved buffer content, configured executable, correct loclist filename/line/column/message, no global quickfix mutation, no-findings notification, unsupported-filetype response, and failure keeps prior loclist. Existing tests pass.
- **Targeted test:** `./tests/run.sh`.

### Task 3.3.1 — README/help documentation and manual smoke workflow

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `README.md`, `doc/novelist.txt`.
- **Can create:** none.
- **Depends on:** `3.2.1`.
- **Spec:** Document the optional external Vale prerequisite and user-owned Vale installation/configuration; `vale.executable` default/override; explicit `:NovelistVale` invocation; supported Markdown/plain-text buffers; current unsaved contents; asynchronous behavior; location-list findings and unchanged quickfix; no auto-linting, styles/config generation, or required dependency. Explain empty-results and launch/process error behavior. Add Neovim 0.12+ manual smoke steps using an independently configured Vale project (including a finding and no-finding run if practical). Keep README and vimdoc consistent and do not claim manual validation unless performed.
- **Constraints / do not touch:** no implementation/test changes; do not bundle Vale config/styles, add manager-specific snippets, or imply Vale is installed/configured by Novelist.
- **Grep anchors:** public config and registration in `lua/novelist/init.lua`, command in `lua/novelist/commands.lua`, adapter behavior in `lua/novelist/vale.lua`, current manual checks in README and `doc/novelist.txt`.
- **Acceptance:** README and help agree on config key/default, command, supported filetypes, async/unsaved behavior, location-list vs quickfix, and optional dependency boundary; `make test` and `make docs-check` pass. Record whether manual Neovim 0.12+ Vale smoke was actually possible/performed; never claim success without evidence.
- **Targeted test:** `make test` and `make docs-check`; manual Neovim 0.12+ smoke test when configured Vale is available.

### Task 3.4.1 — Correct real-Vale stdin invocation

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `lua/novelist/vale.lua`, `tests/unit/vale_test.lua`.
- **Can create:** temporary Vale config/styles, sample drafts, and fake executables under the OS temp directory only; do not leave repository artifacts.
- **Depends on:** `3.3.1` (the end-to-end manual check exposed this issue after the public behavior was documented).
- **Spec:** Fix the adapter's stdin argv so Vale 3.20.0 (and the documented supported CLI behavior) actually lints the supplied unsaved buffer text. The existing adapter appends a `-` positional, which the observed Vale 3.20.0 invocation treats as a filename and returns empty JSON even when stdin contains a known finding; the same stdin and `--path` without `-` produced the finding. Preserve explicit asynchronous execution, `--output=JSON`, path/extension association, user-owned config discovery, result classification and error behavior. Add regression coverage asserting the exact argv omits the unsupported positional and that controlled real/fake process behavior retains diagnostics. Do not alter command/UI integration or documentation unless a narrowly necessary clarification is approved by the orchestrator.
- **Constraints / do not touch:** do not edit `commands.lua`, `init.lua`, integration tests, README/help, or add dependencies; do not create repo config/styles; no synchronous execution or shell interpolation.
- **Grep anchors:** argv construction and JSON parsing in `lua/novelist/vale.lua`; adapter tests in `tests/unit/vale_test.lua`; manual smoke evidence in `planning/STATE_3.md` under `## 3.3.1` and discovered issue in `planning/tasks/3.3.1.todo.md`.
- **Acceptance:** `./tests/run.sh` passes with a regression test for the correct stdin argv; perform the documented Neovim 0.12+ `:NovelistVale` smoke against a temporary configured Vale project and confirm a known finding reaches the invoking window's location list while global quickfix remains unchanged. Also confirm no-findings behavior. Record exact evidence; do not claim success if configuration/runtime prevents the check.
- **Targeted test:** `./tests/run.sh`; manual Neovim 0.12+ Vale smoke.

## Hazards and handoff notes

- Vale needs a user-owned `.vale.ini` and styles; local availability of `/usr/bin/vale` does not make it a project dependency. Avoid tests relying on local config or network.
- Verify exact JSON schema and exit codes with a controlled fake/fixture invocation. A nonzero status may mean findings, not execution failure; classify deliberately.
- `vim.system` callbacks execute in a fast event context; schedule editor API calls. Capture buffer and invoking window before async work. Location lists are window-local: if the invoking window closes or stops displaying the source buffer before completion, do not redirect results to another window.
- Avoid shell interpolation: invoke executable and arguments as an argv list. Do not overwrite global quickfix or alter a loclist on failure.
- Preserve external tool output when producing actionable errors, but avoid noisy success notifications when findings are displayed.
- The command and setup option are public API: README and vimdoc must match; no keymap is added.

## Plan review

- **Spec axis:** all roadmap scope and user decisions map to tasks or explicit deferrals; no narrative interpretation, other checkers, installation, auto-linting, or new formats are added. ADRs remain unsuperseded.
- **Standards axis:** tasks are dependency ordered, bounded to separate adapter/integration/docs/repair phases, with explicit files, anchors, acceptance and commands. Each task fits a <=12-step micro-plan; temporary test executables/config are restricted to OS temp. The adapter isolates parsing/process concerns; integration owns Neovim UI and async lifecycle; docs close the public contract. A manual smoke failure discovered an adapter regression, so Task 3.4.1 was added rather than widening the docs task's files.
- Vale JSON's concrete shape and findings exit status must be confirmed during Task 3.1.1; unnamed buffers should use filetype-derived extension, while named buffers pass their path. User-owned Vale configuration discovery should follow Vale defaults rather than inventing a Novelist config option.
- Review finding resolved: async location-list ownership now explicitly captures the invoking window and avoids mutating another window's list if it is no longer valid for the source buffer.
- Execution finding: the real-Vale smoke exposed that the trailing `-` argument suppresses stdin findings in Vale 3.20.0; Task 3.4.1 is a bounded adapter repair and end-to-end verification, not scope expansion.
- Execution complete: Task 3.4.1 removed the trailing `-`; 49 automated tests pass, and the configured Vale 3.20.0 / Neovim 0.12.5 smoke verified finding and no-finding behavior while preserving global quickfix. Details are in `planning/STATE_3.md`.
