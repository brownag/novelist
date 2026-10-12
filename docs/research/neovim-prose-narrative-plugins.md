# Neovim prose/narrative writing plugins: primary-source research

Date: 2026-10-12

## Question

What existing Neovim/Vim plugins are useful for prose/narrative writing rather than code, and where are the strongest opportunities to build a new plugin?

## Source policy

This note uses primary sources only: Neovim help/source docs, plugin READMEs/docs from the plugin repositories, and first-party tool docs/repos.

## Baseline Neovim capabilities for prose

Neovim already has several prose-friendly primitives that a plugin can compose instead of reimplementing:

- Plugins are loaded from `plugin/` directories on `runtimepath`; filetype plugins belong under `ftplugin/`; package installs can live under `site/pack/*/start` or `site/pack/*/opt` and optional packages can be loaded with `:packadd`.[^nvim-user-plugin][^nvim-filetype-plugin][^nvim-runtimepath]
- Lua plugins can put eager startup code in `plugin/`, lazy modules in `lua/`, and load those modules with `require()`; `require()` searches `lua/` directories on `runtimepath` and caches modules on first use.[^nvim-lua-plugin]
- Filetype plugins load when filetype plugins are enabled, and Neovim documents `ftplugin/<filetype>.vim`, `ftplugin/<filetype>_<name>.vim`, and `ftplugin/<filetype>/<name>.vim` as recognized layouts.[^nvim-ftplugin-layout]
- Built-in spell checking is real-time and supports `:setlocal spell spelllang=en_us`, `]s`/`[s` navigation, `z=` suggestions, adding/removing words, `spellfile`, and multiple languages; the help explicitly says built-in spell checks words only and is not a grammar checker.[^nvim-spell]
- For visual prose layout, built-in options matter: `wrap` visually wraps long lines without inserting newlines, `linebreak` wraps at word boundaries, `breakindent` keeps wrapped display lines visually indented, and `textwidth` hard-wraps inserted text when nonzero.[^nvim-wrap][^nvim-linebreak][^nvim-breakindent][^nvim-textwidth]

## Existing plugins/tools, grouped by writing job

### 1. Drafting environment / focus

| Tool | What primary source says | Use for prose/narrative |
|---|---|---|
| `junegunn/goyo.vim` | README: “Distraction-free writing in Vim”; `:Goyo` toggles or resizes a focused writing window; defaults include width `80`, height `85%`, and it can trigger `GoyoEnter`/`GoyoLeave` callbacks.[^goyo] | Strong minimal focus mode. Mature Vimscript. Good if you want fewer UI elements while drafting. |
| `junegunn/limelight.vim` | README: “Hyperfocus-writing in Vim”; dims surrounding paragraphs; `:Limelight`, `:Limelight!`, and visual-range usage are documented; README says it is “Best served with Goyo.vim”.[^limelight] | Sentence/paragraph focus. Especially good for line editing and revision passes. |
| `folke/zen-mode.nvim` | README: opens the current buffer in a full-screen floating window, hides statusline, can hide number/sign/fold columns, supports callbacks, and can integrate with Twilight.[^zen] | Modern Lua/Neovim focus-mode alternative. More Neovim-native than Goyo. |
| `folke/twilight.nvim` | README: dims inactive portions, uses Tree-sitter where available, pairs with `zen-mode`, and can be toggled with `:Twilight` commands.[^twilight] | Works well for editing one paragraph/section while keeping surrounding text visible. Its README frames it for code, but the mechanism is useful for prose. |

### 2. Prose-oriented editing settings

| Tool | What primary source says | Use for prose/narrative |
|---|---|---|
| `preservim/vim-pencil` | Repo README is `README.markdown`; plugin is distributed as a Vim runtime plugin with `autoload/`, `plugin/`, and `doc/` directories.[^pencil-repo] | Likely the closest existing “writing mode” plugin for Vim/Neovim. Because the repo uses classic Vim runtime layout, inspect its docs/config before writing a replacement. |
| Built-in `ftplugin` + options | Neovim docs define filetype plugin layout and prose-related options (`spell`, `wrap`, `linebreak`, `breakindent`, `textwidth`).[^nvim-ftplugin-layout][^nvim-spell][^nvim-wrap] | A small personal prose plugin may only need filetype-local option sets for `markdown`, `text`, `asciidoc`, `org`, etc. |

### 3. Spelling, grammar, and style checking

| Tool | What primary source says | Use for prose/narrative |
|---|---|---|
| Built-in spell | Neovim help: `:setlocal spell spelllang=en_us`; built-in spell highlights bad/capitalized/rare/local words and supports suggestions; it “only checks words for spelling, there is no grammar check.”[^nvim-spell] | Always enable for prose buffers. Use external grammar/style tools for more. |
| `valentjn/ltex-ls` | README: LTeX LS implements Language Server Protocol and provides grammar/spelling diagnostics; it supports BibTeX, ConTeXt, Git commit messages, LaTeX, Markdown, Org, Quarto, reStructuredText, R Markdown, R Sweave, and XHTML; it bundles what it needs and can use external LanguageTool servers.[^ltex-ls] | Best LSP-shaped answer for grammar/spelling diagnostics inside Neovim. Useful with `nvim-lspconfig` or a thin plugin wrapper. |
| `rhysd/vim-grammarous` | README: powerful grammar checker for Vim; `:GrammarousCheck` checks the current buffer/range with LanguageTool, highlights errors, shows an info window, supports async jobs on Vim/Neovim, and can use location list.[^grammarous] | Existing non-LSP LanguageTool integration. Good for manual revision checks, less ideal for continuous feedback. |
| `davidbeckingsale/writegood.vim` | README: “Writegood is a plugin to highlight common writing problems”; it uses the `Error` highlight group.[^writegood] | Lightweight style smell highlighter. Older/simpler; useful reference for minimal style-rule UI. |
| Vale | README: “A command-line linter for prose”; it enforces your style guide, parses markup including Markdown/AsciiDoc/reStructuredText/HTML, can lint prose in comments/docstrings via tree-sitter, uses YAML rules, and runs locally.[^vale] | Strong style-checking backend. Opportunity: make a polished Neovim UX around Vale diagnostics, rule suppression, vocab, and project styles. |

### 4. Markdown / notes / manuscript structure

| Tool | What primary source says | Use for prose/narrative |
|---|---|---|
| `MeanderingProgrammer/render-markdown.nvim` | README: “Improve viewing Markdown in Neovim”; renders Markdown components including headings, paragraphs, code, thematic breaks, bullets, checkboxes, block quotes/callouts, tables, links, WikiLinks, inline highlights, YAML, HTML comments, and LaTeX blocks; can change window options between rendered/raw views and supports visible-range rendering for large files.[^render-markdown] | Excellent for readable Markdown drafting without leaving Neovim. Useful for notes, essays, and Markdown manuscripts. |
| `obsidian-nvim/obsidian.nvim` | README: plugin for Obsidian vaults; complements rather than replaces Obsidian; features include async completion for note references/tags, navigation via links/backlinks/tags, image paste, sync support, daily notes, templates, quick switch, search, backlinks, and follow link.[^obsidian] | Best fit if narrative work lives in an Obsidian vault, worldbuilding wiki, research notes, or linked Markdown corpus. |
| `renerocksai/telekasten.nvim` | README: Neovim Lua plugin for a text-based Markdown zettelkasten/wiki/journal; highlights include finding notes by name/tag/text, daily/weekly/monthly/quarterly/yearly notes, multiple vaults, note links/templates/backlinks, heading/paragraph links, todos, images, and calendar support.[^telekasten] | Good for story bible, research archive, character/location notes, and drafting journal. |
| `nvim-orgmode/orgmode` | README.org: Orgmode clone in Lua for Neovim; features include agenda view, search by tags/keyword, clocking time, repeatable dates, capture/refile, export through Emacs/Pandoc/custom options, calendar popup, headline movement/refile, TODO states, tags, and checkboxes.[^orgmode] | Useful if you prefer Org files for outlines, tasks, project planning, and drafts. |
| `nvim-neorg/neorg` | README: Neorg is a Neovim plugin to “reimagine organization”; says to “start writing some notes”; mentions tasks, project tracking, slideshows, writing typeset documents, and more.[^neorg] | Larger ecosystem for notes/documents. Better for writers who accept a Neorg-specific format. |

## Where existing coverage is strong

1. **Focus modes are solved enough.** Goyo/Limelight and Zen/Twilight already cover distraction-free windows and paragraph/region dimming.[^goyo][^limelight][^zen][^twilight]
2. **Markdown rendering is strong.** `render-markdown.nvim` covers most display niceties a Markdown prose writer wants: headings, bullets, checkboxes, quotes/callouts, links/WikiLinks, tables, and LaTeX.[^render-markdown]
3. **Vault/wiki workflows are strong.** Obsidian.nvim and Telekasten cover backlinks, tags, link navigation, daily notes, templates, images, and note search.[^obsidian][^telekasten]
4. **Grammar/style backends exist.** LTeX LS, LanguageTool via grammarous, built-in spell, writegood, and Vale cover diagnostics/backends at different depths.[^nvim-spell][^ltex-ls][^grammarous][^writegood][^vale]

## Gaps worth building

### Gap A: “Narrative revision cockpit”

Existing tools catch spelling/grammar/style, but they do not appear to provide a writer-specific revision workflow that tracks story-level concerns. A useful plugin could add:

- scene/chapter outline extraction from Markdown/Org/Neorg headings;
- word counts by scene/chapter/POV/status;
- TODO/FIXME plus custom manuscript tags such as `@pov`, `@location`, `@timeline`, `@character`;
- quickfix/location-list views for continuity markers;
- commands like `:ProseSceneNext`, `:ProsePOV`, `:ProseWordCount`, `:ProseRevisionPass passive|filter|dialogue|sensory`.

Why this gap is real: existing primary docs focus on focus mode, Markdown rendering, note navigation, general grammar/style diagnostics, or organization—not narrative continuity/revision as a first-class workflow.[^goyo][^render-markdown][^obsidian][^telekasten][^ltex-ls][^vale]

### Gap B: Thin Neovim UX over Vale for fiction/prose style

Vale is a strong local prose linter and supports custom YAML rules/styles.[^vale] A plugin could make Vale pleasant in Neovim by:

- exposing diagnostics through Neovim's diagnostic API;
- project style bootstrap (`:ValeInit fiction`, `:ValeSync`);
- commands to accept terms into vocabulary;
- suppress-this-rule code actions;
- per-buffer prose profiles: fiction, technical docs, academic, blog;
- quick navigation by rule/category.

This should probably be a thin wrapper, not a new linter.

### Gap C: Minimal “prose ftplugin” preset

Many writers may not need a large plugin. A small plugin could set sane local options for prose filetypes:

```lua
vim.opt_local.spell = true
vim.opt_local.spelllang = { 'en_us' }
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.textwidth = 0
```

All of these settings are supported by Neovim core docs.[^nvim-spell][^nvim-wrap][^nvim-linebreak][^nvim-breakindent][^nvim-textwidth] Add optional integrations for Zen/Twilight, LTeX, Vale, and render-markdown if installed.

### Gap D: Manuscript export/check pipeline integration

Orgmode and Neorg mention export/document features, and Obsidian/Telekasten focus on notes/vaults.[^orgmode][^neorg][^obsidian][^telekasten] A prose-specific plugin could provide a neutral project pipeline:

- compile chapters in order from a manifest;
- run Vale/LTeX/spell passes;
- export through Pandoc or user commands;
- produce submission formats or preview artifacts;
- preserve source as plain Markdown/Org/text.

## Recommended approach if building a new plugin

Build a small Lua plugin rather than a monolith:

1. **Core:** filetype-local prose settings and commands under `plugin/` + lazy Lua modules under `lua/`, matching Neovim's documented Lua plugin pattern.[^nvim-lua-plugin]
2. **Diagnostics adapters:** optional integrations for LTeX LS and Vale. Do not reimplement grammar/style engines.[^ltex-ls][^vale]
3. **Structure parser:** start with Markdown headings via Tree-sitter or simple line parsing; later support Org/Neorg if needed.
4. **UI:** use quickfix/location lists for revision findings first; floating windows and Telescope pickers can be optional.
5. **Interop:** detect and cooperate with `render-markdown.nvim`, `zen-mode.nvim`, `twilight.nvim`, Obsidian, and Telekasten instead of competing with them.[^render-markdown][^zen][^twilight][^obsidian][^telekasten]

## Shortlist to try before building

For a prose/narrative Neovim setup, try this stack first:

- Focus: `zen-mode.nvim` + `twilight.nvim`, or `goyo.vim` + `limelight.vim`.[^zen][^twilight][^goyo][^limelight]
- Markdown readability: `render-markdown.nvim`.[^render-markdown]
- Grammar/spelling: built-in `spell` + LTeX LS; optionally Vale for house style.[^nvim-spell][^ltex-ls][^vale]
- Notes/story bible: Obsidian.nvim or Telekasten; Orgmode/Neorg if you prefer those formats.[^obsidian][^telekasten][^orgmode][^neorg]
- Existing prose editing reference: inspect `vim-pencil` before implementing text wrapping/pencil-mode behavior yourself.[^pencil-repo]

## Sources

[^nvim-user-plugin]: Neovim `usr_05.txt`, “Adding a package” and “Adding a plugin”: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/usr_05.txt
[^nvim-filetype-plugin]: Neovim `filetype.txt`, filetype plugin loading and plugin details: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/filetype.txt
[^nvim-runtimepath]: Neovim `options.txt`, `runtimepath` lists `autoload/`, `ftplugin/`, `lua/`, `plugin/`, `spell/`, and package behavior: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/options.txt
[^nvim-lua-plugin]: Neovim `lua-guide.txt`, Lua plugin layout, `plugin/`, `lua/`, and `require()`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/lua-guide.txt
[^nvim-ftplugin-layout]: Neovim `usr_05.txt`, filetype plugin names `ftplugin/<filetype>.vim`, `ftplugin/<filetype>_<name>.vim`, `ftplugin/<filetype>/<name>.vim`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/usr_05.txt
[^nvim-spell]: Neovim `spell.txt`, quick start and limitations: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/spell.txt
[^nvim-wrap]: Neovim `options.txt`, `'wrap'`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/options.txt
[^nvim-linebreak]: Neovim `options.txt`, `'linebreak'`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/options.txt
[^nvim-breakindent]: Neovim `options.txt`, `'breakindent'`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/options.txt
[^nvim-textwidth]: Neovim `options.txt`, `'textwidth'`: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/options.txt
[^goyo]: `junegunn/goyo.vim` README: https://raw.githubusercontent.com/junegunn/goyo.vim/master/README.md
[^limelight]: `junegunn/limelight.vim` README: https://raw.githubusercontent.com/junegunn/limelight.vim/master/README.md
[^zen]: `folke/zen-mode.nvim` README: https://raw.githubusercontent.com/folke/zen-mode.nvim/main/README.md
[^twilight]: `folke/twilight.nvim` README: https://raw.githubusercontent.com/folke/twilight.nvim/main/README.md
[^pencil-repo]: `preservim/vim-pencil` repository contents / README.markdown: https://api.github.com/repos/preservim/vim-pencil/contents and https://raw.githubusercontent.com/preservim/vim-pencil/master/README.markdown
[^ltex-ls]: `valentjn/ltex-ls` README: https://raw.githubusercontent.com/valentjn/ltex-ls/develop/README.md
[^grammarous]: `rhysd/vim-grammarous` README: https://raw.githubusercontent.com/rhysd/vim-grammarous/master/README.md
[^writegood]: `davidbeckingsale/writegood.vim` README: https://raw.githubusercontent.com/davidbeckingsale/writegood.vim/master/README.md
[^vale]: Vale README: https://raw.githubusercontent.com/errata-ai/vale/v3/README.md
[^render-markdown]: `MeanderingProgrammer/render-markdown.nvim` README: https://raw.githubusercontent.com/MeanderingProgrammer/render-markdown.nvim/main/README.md
[^obsidian]: `obsidian-nvim/obsidian.nvim` README: https://raw.githubusercontent.com/obsidian-nvim/obsidian.nvim/main/README.md
[^telekasten]: `renerocksai/telekasten.nvim` README: https://raw.githubusercontent.com/renerocksai/telekasten.nvim/main/README.md
[^orgmode]: `nvim-orgmode/orgmode` README.org: https://raw.githubusercontent.com/nvim-orgmode/orgmode/master/README.org
[^neorg]: `nvim-neorg/neorg` README: https://raw.githubusercontent.com/nvim-neorg/neorg/main/README.md
