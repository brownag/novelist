# Execution Plan 5 — lazy.nvim guidance and local install target

## Goal & Scope

### Goal

Make Novelist easier to install and configure for the user's selected lazy.nvim workflow while retaining a manager-independent standalone plugin. Add a safe Makefile install/uninstall path that symlinks this checkout into Neovim's standard user package directory, and document that path plus a lazy.nvim example in README. Do not add runtime integration for either installer or plugin manager.

### In scope
- Add `make install` and `make uninstall` targets that link the checkout to `$(INSTALL_DIR)`, defaulting under Neovim's user data directory (`$XDG_DATA_HOME/nvim`, or `$HOME/.local/share/nvim` when unset).
- Permit full destination override through `INSTALL_DIR`.
- Make install idempotent when the destination is already a symlink to this checkout; refuse to replace any other existing destination. Make uninstall remove only the matching symlink and otherwise leave the destination untouched.
- Document the Makefile install/uninstall workflow and a lazy.nvim plugin-spec example in `README.md` only.
- Validate installation behavior against a temporary destination, including safe existing-destination handling.

### Out of scope / deferred
- Plugin-manager-specific runtime adapters, dependencies, or changes to the plugin's loading/setup behavior.
- Changes to `doc/novelist.txt`; the user confirmed installation documentation belongs in README because help is available only after the plugin is installed.
- Changes to keymap or Tree-sitter/document-map features: user-configurable keymaps and optional Tree-sitter fallback already exist in the current codebase.
- Other managers, additional parser integrations, changes to prose behavior, and all later roadmap phases.

### Verbatim constraints and user statements
- Master Plan: “Keep the plugin standalone Lua, with no required third-party dependencies.”
- Master Plan: “Preserve ADR 0001: no required third-party dependencies.”
- User: “lazy.nvim seems like worthwhile”
- User: “yes, also i want an easy install method via the makefile or otherwise”
- User: “yes symlink”
- User accepted: install/uninstall defaults to the current user's Neovim package directory and allows an overridden destination.
- User accepted: “succeed if it’s already the symlink to this checkout; otherwise stop with a clear error and leave the existing file or directory untouched. `make uninstall` should likewise remove only that matching symlink.”
- User: “yes, i think novelist specific help relies on being installed first?” (README-only installation guidance.)
- User accepted: exercise install/uninstall against a temporary Neovim data directory, including existing-destination safety.

## Decision log (2026-10-16)

1. **Phase relevance:** Keymaps and optional Tree-sitter document-map parsing are already implemented; exclude them rather than re-open completed features.
2. **Manager scope:** Add a lazy.nvim user-side plugin-spec example; no manager-specific adapter or dependency.
3. **Install method:** Add Makefile `install`/`uninstall` targets using a symlink to the checkout.
4. **Default/override:** Default destination is `$(XDG_DATA_HOME)/nvim/site/pack/novelist/start/novelist` when `XDG_DATA_HOME` is set, otherwise `$(HOME)/.local/share/nvim/site/pack/novelist/start/novelist`. Allow the full destination to be overridden as `INSTALL_DIR=...`.
5. **Safety:** An already-correct symlink is an idempotent success. Any other existing destination is an error and must remain untouched. Uninstall removes only the symlink that points to this checkout; otherwise it is a no-op or clear report without modifying that destination.
6. **Documentation:** README only; no vimdoc install section because help depends on runtime installation.
7. **Validation:** Exercise both Make targets against an OS-temp destination; verify symlink target, idempotence, conflict preservation, and uninstall safety. Run `make test` and `make docs-check` serially.
8. **Architecture:** No ADR superseded. Work must comply with ADR 0001 (standalone, no required dependencies) and ADR 0002 (no default keymaps; existing opt-in behavior unchanged).

## Reconnaissance

- Repo: `/home/andrew/workspace/novelist`; current HEAD `a7e5158` (`fix(vale): lint unsaved stdin correctly`). Existing user changes are Plan 4 artifacts and `tests/unit/vale_test.lua`; leave them untouched.
- Baseline: `make test` → 49 passed, 0 failed. `make docs-check` passed (quiet success). Runtime available is Neovim 0.12.5. No generated docs files were created by `make docs-check`.
- Canonical commands: `make test`, `make docs-check`, `make clean`; root `AGENTS.md` says `make` lists targets and `make test` runs `./tests/run.sh`.
- Entry points/sizes: `plugin/novelist.lua` 1 line; `lua/novelist/init.lua` 95; `lua/novelist/commands.lua` 388; `lua/novelist/keymaps.lua` 174; `lua/novelist/document_map.lua` 276; `tests/run.sh` 19; README 278; vimdoc 422.
- Makefile currently has only `help`, `test`, `docs-check`, and `clean`; `.DEFAULT_GOAL := help`, Bash shell, and target help generated from `##` comments. It has no install behavior.
- README currently gives manager-generic setup guidance, documents the opt-in keymap preset and optional Tree-sitter fallback, but has no lazy.nvim-specific plugin spec and no Makefile install workflow.
- `plugin/novelist.lua` calls `require('novelist').setup()`; standard Neovim package loading can discover a symlink under `site/pack/*/start/*`. Do not alter plugin runtime behavior.
- Tests are a dependency-free Neovim harness launched by `tests/run.sh`; no Makefile behavior test harness exists. Install/uninstall acceptance will use a temporary full `INSTALL_DIR` and shell assertions, avoiding writes to the user's Neovim data directory.
- Accepted ADRs 0001 and 0002 remain active. No conflict or supersession is proposed.
- Existing code already covers user-configurable keymaps and optional parser fallback; this plan is strictly for installation documentation and a local symlink installer.

## Wave table

| Wave | Tasks | Purpose | Dependencies |
|---|---|---|---|
| 1 | `5.1.1` | Add safe Makefile install/uninstall targets | — |
| 2 | `5.2.1` | Document Makefile installation and lazy.nvim configuration | `5.1.1` |

Tasks are sequential because README instructions must match the implemented target and its exact safety behavior. One worker per wave; no within-wave concurrency is required.

## Task specifications

### Task 5.1.1 — Safe local Makefile install/uninstall

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `Makefile`.
- **Can create:** OS-temp-only installation targets/fixtures for validation; remove them after testing. Update `planning/tasks/5.1.1.todo.md` and append report to `planning/STATE_5.md`.
- **Depends on:** none.
- **Spec:** Add help-documented, phony `install` and `uninstall` targets. `install` must create parent directories and symlink the repository checkout to `$(INSTALL_DIR)`. Default `INSTALL_DIR` to Neovim's standard user package location under `$XDG_DATA_HOME/nvim` when set, else `$HOME/.local/share/nvim`, specifically `site/pack/novelist/start/novelist`. `INSTALL_DIR` is a full target-path override. If the target is already a symlink resolving to this checkout, succeed without changing it. If any other file, directory, or symlink occupies the target, fail clearly without modifying it. `uninstall` removes only a symlink at `INSTALL_DIR` that resolves to this checkout; do not remove an unrelated destination or prune parent directories. Keep targets dependency-free and avoid shell interpolation of untrusted values beyond normal Make variable path use.
- **Constraints / do not touch:** Do not change plugin code, tests, README/help, or user configuration; no `sudo`, no writes outside the target selected by `INSTALL_DIR`/default, no copying, no overwriting, no unrelated cleanup.
- **Grep anchors:** existing target/help style in `Makefile`; runtime entry point `plugin/novelist.lua`; package loading convention documented by Neovim's `pack/*/start/*` runtime layout.
- **Acceptance:** In a temporary directory, `make install INSTALL_DIR="$tmp/site/pack/novelist/start/novelist"` creates a symlink resolving to the repo. Re-running install succeeds. With an unrelated file and then an unrelated symlink at the destination, install fails and each destination remains unchanged. `make uninstall INSTALL_DIR=...` removes the matching link, and leaves unrelated existing destinations untouched. Check `make` help lists both targets and run `git diff --check`.
- **Targeted test:** The exact temporary-destination shell checks above; `make` for help.

### Task 5.2.1 — README lazy.nvim and local install guidance

- **Repo:** `/home/andrew/workspace/novelist`
- **Files in scope — must edit:** `README.md`.
- **Can create:** none. Update `planning/tasks/5.2.1.todo.md` and append report to `planning/STATE_5.md`.
- **Depends on:** `5.1.1`.
- **Spec:** Replace or supplement generic installation prose with a concise lazy.nvim spec example using the repository URL, normal `opts` setup, and a `cmd` list for Novelist commands so lazy loading is clear. Include `:NovelistDocumentMap` and `:NovelistVale` with current public commands as appropriate; don't invent API fields or imply required dependencies. Also document `make install` / `make uninstall`, the default user package path, `INSTALL_DIR` override, symlink semantics (checkout updates are immediately visible), conflict safety, and that `:help novelist` is available after installation/runtimepath setup. Keep manager-generic installation possible and state that lazy.nvim remains optional. Do not update vimdoc because install guidance is README-only by user decision.
- **Constraints / do not touch:** No runtime changes, plugin-manager adapter, dependencies, help changes, or claims that make install configures lazy.nvim. Keep documented commands and defaults consistent with Task 5.1.1.
- **Grep anchors:** README Installation section and public commands in README; `Makefile` target names/default path/override from Task 5.1.1; runtime auto-setup in `plugin/novelist.lua`.
- **Acceptance:** README clearly documents both installation routes without suggesting manager integration is required; lazy spec's `opts`/`cmd` use only existing API/commands. `make test` and `make docs-check` pass; `git diff --check` passes.
- **Targeted test:** `make test`; `make docs-check`.

## Hazards and handoff notes

- Do not assume the checkout's `HOME`/`XDG_DATA_HOME` is safe for testing. Always use explicit temporary `INSTALL_DIR` during execution validation.
- Treat dangling symlinks as occupied destinations; do not overwrite them. Confirm current checkout and existing target via physical/canonical paths consistently.
- Avoid removing parent directories on uninstall; they may contain user data or other packages.
- README lazy.nvim snippet is user configuration only. Keep runtime standalone and manager-agnostic.
- Current uncommitted Plan 4 artifacts and test modification are user work; workers must not alter them.

## Plan review

- **Spec axis:** The master-plan phase's integration candidates are mapped: lazy.nvim guidance is in scope; keymaps and optional parser integration are explicitly excluded because code and docs already provide them. Install/uninstall were explicitly added by user request. No later roadmap phase is pulled in.
- **Standards axis:** Tasks are small, sequential, and file scopes disjoint across waves. Each task has explicit paths, constraints, anchors, acceptance commands, and bounded micro-plan size. Install safety includes occupied/dangling symlink handling, idempotence, scoped uninstall, and temp-only validation. ADRs remain honored.
- **Open verification:** During Task 5.1.1, verify that path/symlink comparisons work for relative and absolute `INSTALL_DIR` values and handle a dangling destination without replacement; document the supported behavior precisely.
