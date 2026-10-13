---
name: neovim-plugins
description: How to design, write, test and document Neovim plugins in Lua for Neovim 0.12+, plus appendices on adding a Rust native module via mlua. Use this skill whenever the task touches a Neovim plugin — creating one, adding a user command, keymap, autocmd, setup()/config option, health check, highlight, extmark, floating window, vimdoc help file, or headless test — and whenever someone asks about plugin/ vs lua/ layout, lazy loading, vim.api/vim.uv/vim.system usage, deprecated Neovim APIs, or making plugin code faster with Rust, mlua, cdylib, LuaJIT native modules or prebuilt binaries. Use it even if the user just says "add a command to my nvim plugin" or "why is my plugin slow to start".
---

# Writing Neovim plugins (Lua, Neovim 0.12+)

This skill is the working knowledge for building a plugin that feels native: cheap at startup, safe to configure, discoverable through `:help` and `:checkhealth`, and tested headlessly. Neovim's own guide (`:h lua-plugin`) is the upstream source for most of this; when in doubt, read it in the installed runtime rather than trusting memory — the API moves every release.

Two appendices cover Rust native modules. Read them only when the task involves Rust/mlua or a performance problem that Lua genuinely can't solve:

- `references/appendix-a-mlua.md` — building a Rust module with mlua: Cargo setup, entry points, calling `vim.*`, threading, performance, testing. Includes a template verified against mlua 0.12.2 + Neovim 0.12.6.
- `references/appendix-b-mlua-shipping.md` — distributing the binary: per-platform builds, loaders, version matching, the "can't unload a .so" problem, failure table, and mlua vs nvim-oxi vs RPC.
- `assets/mlua-template/` — copyable crate + Lua loader.

## First, orient yourself

Before writing code, find out what you're working with, because conventions matter more than cleverness in a plugin:

1. Check the Neovim version the plugin targets (README, `vim.fn.has('nvim-0.x')` guards, CI). APIs differ between 0.10, 0.11 and 0.12; see "API drift" below.
2. Read the existing layout, test runner and help file. Match the plugin's style for config merging, error reporting and tests — don't introduce busted or a new config DSL into a plugin that has its own.
3. When unsure about an API, check the local runtime: `nvim --headless --clean -c 'lua print(vim.inspect(...))' -c qa!`, or grep `$VIMRUNTIME/doc/*.txt`. This is fast and beats guessing.

## Layout

```
myplugin/
├── plugin/myplugin.lua      -- runs at startup: commands, <Plug> maps, autocmds. Tiny.
├── lua/myplugin/
│   ├── init.lua             -- public API: setup(), main functions
│   ├── config.lua           -- defaults, merge, validation
│   ├── health.lua           -- :checkhealth myplugin
│   └── *.lua                -- internals, required on demand
├── ftplugin/<ft>.lua        -- filetype-specific setup (optional)
├── doc/myplugin.txt         -- vimdoc, tags like *myplugin-setup*
└── tests/                   -- run with nvim --headless
```

No manifest, no registration: being on `'runtimepath'` is what makes it a plugin.

## Startup cost: `plugin/` defines entry points, `lua/` does the work

`plugin/*.lua` runs for every user on every startup, so it should only *declare* things. Put `require()` inside the command/map/autocmd callback so the real modules load on first use. This is the plugin's own lazy loading; users shouldn't need a plugin manager's lazy config to get fast startup.

```lua
-- plugin/myplugin.lua
if vim.g.loaded_myplugin then return end   -- lets users disable it, prevents double init
vim.g.loaded_myplugin = true

vim.api.nvim_create_user_command('MyPlugin', function(opts)
  require('myplugin.commands').run(opts)
end, {
  nargs = '*',
  complete = function(arglead) return require('myplugin.commands').complete(arglead) end,
  desc = 'MyPlugin commands',
})

vim.keymap.set('n', '<Plug>(MyPluginToggle)', function() require('myplugin').toggle() end)
```

Profile with `nvim --startuptime /tmp/st.log` if startup is a concern.

## Configuration: separate config from initialization

The plugin should work with zero configuration. Two accepted patterns (`:h lua-plugin-init`):

- **`setup(opts)` that only merges config** — calling it is optional, calling it twice is safe, and it doesn't create keymaps or autocmds as a side effect. Initialization lives in `plugin/` or `ftplugin/`.
- **`vim.g.myplugin` table** read and validated lazily at first use — works even if the user's config runs before the plugin is installed.

A combined `setup()` that both configures and initializes is acceptable only when users must opt in, and it means the plugin does nothing until they call it. If you adopt it, document that loudly.

Merge with `vim.tbl_deep_extend('force', defaults, opts or {})` and then validate. Watch the list-vs-map trap: deep-extending list-like tables merges by index, so a user's `{ 'markdown' }` merged over `{ 'markdown', 'text' }` keeps `'text'`. Replace lists wholesale unless you have a reason not to, and say so in the docs.

Validate types with `vim.validate(name, value, validator, optional)` (the positional form; the old table form is deprecated). Fail with a message that names the bad key and what was expected. Typos in keys (unknown fields) are better reported by the health check than by erroring in `setup()`.

## Keymaps: offer, don't impose

Global default keymaps collide with user maps. Prefer, in order:

1. `<Plug>(MyPluginAction)` mappings the user binds with one line.
2. A Lua function / user command.
3. Buffer-local maps only in buffers the plugin owns (its UI, its filetype).

Always pass `desc`. Use `vim.keymap.set` (handles modes, Lua callbacks, `expr`), never `nvim_set_keymap` with string RHS for Lua code.

## User commands

One top-level command with subcommands (`:MyPlugin open`, `:MyPlugin stats`) scales better than many commands. Use `nargs`, `range`, `bang` as appropriate, provide `complete`, and parse `opts.fargs`. Unknown subcommands should produce a clear `vim.notify(..., vim.log.levels.ERROR)` listing the valid ones.

## Autocmds

Create a named augroup with `{ clear = true }` so re-sourcing or calling `setup()` again doesn't stack duplicate handlers. Prefer buffer-local autocmds (`buf = bufnr`) for per-buffer behavior, and filter with `pattern` rather than checking inside the callback. Return `true` from a callback to delete it (one-shot).

## Buffers, windows, options

- Set local options with `vim.bo[buf].x`, `vim.wo[win][0].x` (window-local *for the current buffer in that window*), or `vim.opt_local` for the current context. `vim.wo[win].x` without `[0]` sets the window's value that leaks to other buffers shown there — usually not what a filetype-scoped feature wants.
- `nvim_get_option_value` / `nvim_set_option_value` replace the deprecated `nvim_buf_get_option`/`nvim_win_set_option` family.
- Use `0` for "current" buffer/window only at the call boundary; capture the real handle (`nvim_get_current_buf()`) before anything async, because "current" may change by the time a callback runs. Check `nvim_buf_is_valid` before touching a handle later.
- Byte vs character: API columns are 0-based **byte** offsets; `nvim_win_get_cursor` is (1-based row, 0-based byte col). Prose and non-ASCII text break code that assumes characters. Use `vim.str_utfindex` / `vim.str_byteindex` or `vim.fn.strchars` when counting what the user sees.

## Highlights, namespaces, extmarks

Create a namespace per feature with `nvim_create_namespace('myplugin.feature')`. Define highlight groups with `nvim_set_hl(0, 'MyPluginThing', { link = 'Comment', default = true })` — `default = true` lets colorschemes and users override, and re-applying in a `ColorScheme` autocmd keeps them alive across theme changes. Use extmarks (virtual text, signs, highlights) instead of matchadd/signs; clear by namespace.

## Async and the main loop

Neovim's Lua runs on the main loop; blocking it freezes the editor.

- External processes: `vim.system(cmd, opts, on_exit)`; the callback runs in a fast event context.
- Timers, fs, sockets: `vim.uv` (`vim.loop` is deprecated).
- In fast contexts (uv callbacks, `vim.system` on_exit), most `vim.api` calls error (E5560). Wrap editor work in `vim.schedule(fn)` or `vim.schedule_wrap(fn)`.
- Debounce work triggered by `TextChanged*`/`CursorMoved` with a uv timer; these fire constantly.
- `vim.async` does not exist in 0.12; don't invent it. Coroutines + `vim.schedule` are fine for sequencing.

## Errors and messages

- `vim.notify(msg, level)` for user-facing messages, prefixed with the plugin name. `error()` for programming errors in API functions so callers get a traceback.
- Wrap user-supplied callbacks in `pcall`/`xpcall` so one bad callback doesn't break the plugin's state.
- Use `vim.deprecate()` when renaming public API so users get a migration message.

## Health check

`lua/myplugin/health.lua` exporting `check()` is picked up by `:checkhealth myplugin` automatically. Report: Neovim version meets the minimum, config valid (and unknown keys), optional dependencies/executables present (`vim.fn.executable`), native module loads (if any). Use `vim.health.start/ok/warn/error/info`.

## Documentation

Ship `doc/myplugin.txt` in vimdoc format (`:h help-writing`): a `*myplugin.txt*` header, a contents table, sections with right-aligned `*myplugin-topic*` tags, `|links|`, and `>lua` … `<` code blocks. Document every command, `<Plug>` map, option (with default and type) and public function. Check it with `nvim --headless -c 'helptags doc' -c qa` — duplicate tags error. Keep the README and help file in sync when you change behavior; that drift is the most common doc bug.

## Testing

Tests must run in a real Neovim, because the code under test calls `vim.*`. The minimal harness is a Lua script run headlessly:

```sh
nvim --headless --clean -u NONE -l tests/run.lua      # -l runs a Lua script and exits
```

Guidelines that keep tests trustworthy:

- `--clean` / `-u NONE` so the user's config and other plugins don't leak in. Point `XDG_*` at temp dirs if the plugin writes state.
- Put the plugin root on `package.path` or `'runtimepath'` explicitly in the runner.
- Exit nonzero on failure (`os.exit(1)` / `vim.cmd.cquit()`), or CI will pass silently.
- Test through the public surface — run the user command with `vim.cmd`, feed keys with `nvim_feedkeys(..., 'x', false)` or invoke the `<Plug>` map, fire autocmds with `nvim_exec_autocmds` — then assert on buffer lines, options, extmarks.
- Create a fresh scratch buffer per test and delete it after; reset config between tests.
- For async code, `vim.wait(ms, predicate)` drives the loop until the condition holds.
- Use the plugin's existing harness. If none exists, a ~60-line runner (collect `*_test.lua`, `xpcall`, count, exit code) is enough; mini.test, busted+nlua and plenary are options for larger plugins.

Also keep a short manual smoke-test checklist in the docs for things headless tests can't see (rendering, real UI).

## API drift to watch (0.10 → 0.12)

| Old | Use | Since |
|---|---|---|
| `vim.loop` | `vim.uv` | 0.10 |
| `nvim_buf_get_option` / `nvim_*_set_option` | `nvim_get_option_value` / `nvim_set_option_value` | 0.10 |
| `vim.tbl_islist` | `vim.islist` | 0.10 |
| `vim.tbl_flatten` | `vim.iter(t):flatten():totable()` | 0.10 |
| `vim.validate{ name = {v, 't'} }` | `vim.validate('name', v, 'type')` | 0.11 |
| `vim.highlight` | `vim.hl` | 0.11 |
| `vim.diff` | `vim.text.diff` | 0.12 |
| `buffer =` in `vim.keymap.set`/`del` and `nvim_*_autocmd(s)` | `buf =` | 0.12 |

If the plugin supports older Neovim than the rename, keep the old spelling (it still works with a deprecation) or branch on `vim.fn.has('nvim-0.12')`. Check `:h deprecated` in the installed runtime for the full list. `:restart` (0.12) reloads Neovim with the same session — handy while iterating.

## When to reach for Rust

Lua (LuaJIT) is fast enough for nearly all plugin logic, and editor calls cost the same from Rust as from Lua. A native module earns its complexity only for heavy pure computation over data that can stay on the Rust side: fuzzy matching thousands of items, indexing a file tree, parsing big documents, tokenizing. It adds per-platform builds, a binary that can crash the editor, and users who can't install it. If you go there, read `references/appendix-a-mlua.md` first, keep a pure-Lua fallback, and read `references/appendix-b-mlua-shipping.md` before the first release.

## Before you call it done

- `plugin/` still requires nothing eagerly.
- New config keys: defaults, validation, help-file entry, README entry.
- New command/map: `desc`, completion, help-file entry.
- Tests pass headlessly with a nonzero exit on failure, and new behavior has a test.
- `:checkhealth myplugin` reflects anything new that can be misconfigured.
- `helptags` runs clean.
