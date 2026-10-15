# Integrations and Interaction — Initial Scoping Brief

**Purpose:** Capture repository facts, first-party technical evidence, constraints, risks, and open decisions to frame a future `/plan-wave` plan for the first roadmap phase. This brief is research input, not an implementation plan or approval to change behavior.

## Scope boundary

The roadmap phase is **Integrations and Interaction** (group 5), first in the user-selected sequence 5 → 1 → 2 → 3 → 4. Candidate areas:

- Plugin-manager-specific integration only where it adds clear value.
- Optional parser/runtime integration.
- User-configurable keymaps.

Keep the current standalone behavior usable. Do not add a required third-party dependency or default keymaps: these constraints are recorded in accepted [ADR 0001](../../docs/decisions/0001-dependency-free-lua-plugin-architecture.md) and [ADR 0002](../../docs/decisions/0002-user-respecting-prose-settings-and-command-ux.md). This phase does not include Writing Assistance, Manuscript Workflow, Story Organization, or Format Support.

## Repository baseline

- `plugin/novelist.lua` calls `require('novelist').setup()`; the public module is `lua/novelist/init.lua`.
- `setup(opts)` merges configuration, replaces the `FileType` autocmd group, and registers commands. Current configurable prose behavior and supported filetypes are in `lua/novelist/settings.lua`; default supported filetypes are Markdown and plain text.
- `lua/novelist/commands.lua` provides `:NovelistSceneNext`, `:NovelistScenePrev`, `:NovelistWordCount`, and `:NovelistMarkers [name]`. `README.md` says users may call `setup()` without installing default keymaps; the integration tests assert no keymaps are installed.
- `lua/novelist/cockpit.lua` performs pure line-based heading, count, and marker parsing. Parsing is currently independent of Tree-sitter and editor state.
- `README.md` gives generic plugin-manager installation guidance and has no manager-specific integration code or examples.
- `AGENTS.md` identifies `make test` and `make docs-check` as the canonical test/documentation checks. Baseline observed during this scoping task: `make test` → 22 passed, 0 failed.

## Primary-source findings

### Plugin-manager integration

Plugin managers expose user-side specification and loading mechanisms that can configure or lazy-load plugins without plugin-specific runtime adapters. For example, lazy.nvim's plugin spec has `opts` for configuration, `dependencies`, `keys`, and optional specs; vim-plug documents loading on commands or filetypes with `on` and `for`.

- [lazy.nvim documentation — Plugin Spec](https://github.com/folke/lazy.nvim/blob/main/doc/lazy.nvim.txt#L244) (first-party documentation; see fields `opts`, `dependencies`, `keys`, and `optional`).
- [vim-plug README — On-demand loading of plugins](https://github.com/junegunn/vim-plug#on-demand-loading-of-plugins) (first-party documentation; `on` and `for`).

**Implication:** These are user configuration capabilities; they do not by themselves establish a need for novelist-specific integration code. A manager-specific adapter or documentation example should be justified by a concrete limitation in the generic `setup()` and named-command interface.

### Optional parser/runtime integration

Neovim's built-in `vim.treesitter.get_parser(buf, lang, opts)` documents that it may return a parser or `nil` with an error when a parser cannot be created. The nvim-treesitter project documents language parsers as separately installed components.

- [Neovim `vim.treesitter.get_parser()`](https://neovim.io/doc/user/treesitter.html#vim.treesitter.get_parser()) (official API documentation).
- [nvim-treesitter README — Language parsers](https://github.com/nvim-treesitter/nvim-treesitter#language-parsers) (first-party project documentation).

**Implication:** Tree-sitter availability cannot be assumed. If a future feature demonstrates a real need for syntax-tree semantics, integration would need to remain optional and degrade safely to current line-based behavior when the API or language parser is unavailable. No such feature need has been established by this scoping task.

### User-configurable keymaps

Neovim's `vim.keymap.set()` maps keys to commands or Lua functions and supports buffer-local mappings using `{ buf = ... }`. Its Lua guide also describes deferred invocation patterns that avoid loading a module while defining a mapping.

- [Neovim Lua guide — Creating mappings](https://neovim.io/doc/user/lua-guide.html#lua-guide-mappings-set) (official documentation).
- [Neovim API — `nvim_create_user_command()`](https://neovim.io/doc/user/api.html#nvim_create_user_command()) (official API documentation; novelist already exposes commands that users can map).

**Implication:** Users can bind existing named commands themselves today. If the plugin adds a mapping configuration feature, it should be explicitly user-configured and document its scope; no defaults should be introduced.

## Recommendations for the future `/plan-wave` session

1. Start with the use case: decide whether a manager-specific runtime change is actually needed, or whether a short user-configuration example is sufficient.
2. Preserve the line-based parser as the default. Consider Tree-sitter only if an identified feature materially benefits from syntax-tree semantics; optional loading and graceful fallback are required by the accepted dependency boundary.
3. Treat configurable mappings as a separate decision from adding keymaps. Users already have commands to map; decide whether a plugin-level mapping option provides value beyond documented user-side `vim.keymap.set()` calls.
4. Keep any actual implementation goal bounded. The candidate areas need not all be combined into one execution plan if research shows they are independent or no code change is warranted.

## Open decisions for `/plan-wave`

- Which concrete user problem is not served by the existing generic installation guidance and public `setup()`/commands?
- Are any plugin-manager examples worth maintaining, and if so, which manager(s) matter to the user? Examples alone do not imply runtime integration.
- What feature, if any, needs parser/runtime integration? Which formats or syntax semantics are involved, and can line-based behavior remain the fallback?
- Does the user want novelist to install mappings from configuration, or is documenting user-defined mappings enough? If plugin-managed mappings are desired, decide configuration shape, modes, global vs buffer-local scope, naming, override behavior, and when they are installed.
- What tests and documentation changes are needed for the selected scope, and what manual smoke coverage is required?

## Explicit non-decisions

This brief does not select a plugin manager, add a dependency, adopt Tree-sitter, define mapping names/configuration, or authorize implementation. It does not supersede ADR 0001 or ADR 0002. Any proposal that changes those decisions must return to the user for explicit resolution before an execution plan is drafted.
