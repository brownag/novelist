# novelist

`novelist` is a small, dependency-free Neovim plugin for prose writers. It combines prose-friendly buffer settings with a lightweight revision cockpit for Markdown and plain-text drafts.

It provides:

- automatic local prose options for supported buffers;
- heading-based section navigation;
- current-section and document word counts;
- configurable standalone story/revision markers such as `@who:` and `@todo:`.

`novelist` does not infer story meaning automatically, and it does not provide grammar or style checking.

## Requirements

- Neovim 0.12+ is the release target.
- No required third-party Neovim plugins or external tools.

The dependency-free test suite can run under the available local Neovim runtime, but passing it on an older runtime does not replace the required manual Neovim 0.12+ smoke test for release validation.

## Installation

Install the repository with your preferred Neovim plugin manager, using the manager's normal syntax for a plugin repository. For example, in generic terms:

```lua
-- Add the novelist repository with your plugin manager.
-- Then configure it after the plugin is on 'runtimepath':
require('novelist').setup()
```

The runtime plugin calls `require('novelist').setup()` with defaults when it loads. Calling `setup()` yourself is safe and updates the active configuration without installing default keymaps.

## Configuration

Default configuration:

```lua
require('novelist').setup({
  prose = {
    enabled = true,
    filetypes = { 'markdown', 'text' },
    spell = true,
    spelllang = { 'en_us' },
    wrap = true,
    linebreak = true,
    breakindent = true,
    textwidth = 0,
  },
  markers = {},
})
```

`prose` options:

| Option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Apply prose settings on supported `FileType` events. |
| `filetypes` | `{ 'markdown', 'text' }` | Filetypes that receive the prose preset. Replaces the default list when configured. |
| `spell` | `true` | Local spell checking value. |
| `spelllang` | `{ 'en_us' }` | Local spell language list; tables are applied as comma-separated spell languages. |
| `wrap` | `true` | Visual wrapping. |
| `linebreak` | `true` | Break wrapped lines at convenient characters when possible. |
| `breakindent` | `true` | Preserve indentation visually on wrapped lines. |
| `textwidth` | `0` | Do not insert hard wraps into saved text. |

Disable automatic prose settings globally:

```lua
require('novelist').setup({
  prose = { enabled = false },
})
```

Disable automatic prose settings for one buffer before its `FileType` event applies:

```lua
vim.b.novelist_disable = true
```

Extend, rename, override, or disable markers with `markers`. Marker descriptions are for user-facing text only; marker values in buffers remain arbitrary text.

```lua
require('novelist').setup({
  markers = {
    who = 'POV first, then other characters present.',
    thread = 'Revision thread or subplot note.',
    todo = false, -- disable the default @todo marker
  },
})
```

## Commands

`novelist` installs named commands only; it does not create default keymaps.

| Command | Description |
| --- | --- |
| `:NovelistSceneNext` | Move to the next Markdown ATX section heading. Warns if there is no next heading. |
| `:NovelistScenePrev` | Move to the previous Markdown ATX section heading. Warns if there is no previous heading. |
| `:NovelistWordCount` | Report current section words and document words with `vim.notify`. |
| `:NovelistMarkers [name]` | Put matching marker lines in the quickfix list. Optional `[name]` filters by marker name, such as `todo`. Opens the quickfix window only when matches exist. |

Sections are based on Markdown ATX headings (`#` through `######` followed by whitespace). A headingless document is treated as one implicit whole-document section for word counts; heading navigation reports that no section heading exists.

## Markers

Markers are standalone Markdown/plain-text metadata lines:

```text
@name: value
```

The marker line may have leading whitespace. Names may contain word characters, `_`, and `-`. Only enabled marker names are recognized; unknown or disabled marker names are ignored. Inline `@` mentions are not parsed.

Default markers:

| Marker | Default description / intended meaning | Example |
| --- | --- | --- |
| `@who` | Viewpoint character first, followed by other important people in the scene. | `@who: Mira (POV), Ivo` |
| `@what` | Central event, conflict, or change in the scene. | `@what: Mira discovers the forged letter` |
| `@where` | Scene location. | `@where: North bridge, east tower` |
| `@when` | Placement in the story chronology. | `@when: Winter, year 12` |
| `@why` | Why the scene matters: its purpose, stakes, or cause in the story. | `@why: Forces Mira to choose whether to trust Ivo` |
| `@todo` | Unresolved drafting/revision task; may appear anywhere and repeat. | `@todo: Seed the letter's wax seal earlier` |

`@why` means scene purpose or stakes by default. You may write character motivation there when useful, but `novelist` treats the value as plain writer-authored text.

## Word-count limitations

Word counts are intentionally simple:

- counts are whitespace-delimited non-empty tokens;
- recognized standalone marker lines are excluded;
- section heading text is counted after stripping the leading Markdown heading prefix;
- other Markdown syntax is not parsed, normalized, or removed;
- sections are heading boundaries only, not inferred chapters or scenes.

## Manual smoke test for Neovim 0.12+

Manual validation on Neovim 0.12+ remains a release gate unless it is actually run on that runtime.

1. Install or add this repository to `runtimepath` with your plugin manager.
2. Start Neovim 0.12+ and run `:checkhealth` or `:version` to confirm the runtime version.
3. Open a Markdown buffer and set `:set filetype=markdown` if needed.
4. Confirm prose settings such as `:setlocal spell? spelllang? wrap? linebreak? breakindent? textwidth?` show the configured defaults.
5. Add sample content:

   ```markdown
   # Opening
   @who: Mira (POV), Ivo
   Mira finds the forged letter.
   @todo: Seed the wax seal earlier

   ## Turn
   Ivo denies everything.
   ```

6. Run `:NovelistWordCount` and confirm it reports section and document counts.
7. Run `:NovelistSceneNext` and `:NovelistScenePrev` from different lines and confirm cursor movement between headings.
8. Run `:NovelistMarkers` and `:NovelistMarkers todo`; confirm matching lines appear in quickfix and that filtering works.
9. Optionally set `vim.b.novelist_disable = true` before applying a supported filetype in a new buffer and confirm prose settings are skipped.

## Automated checks

Run the dependency-free headless suite:

```sh
./tests/run.sh
```

Help documentation should resolve from the plugin runtime path after help tags are generated:

```sh
nvim --headless -u NONE --cmd 'set rtp^=.' -c 'helptags doc' -c 'help novelist' -c 'quitall'
```

If that command creates `doc/tags` during validation, remove it before committing unless the release process explicitly wants generated help tags tracked.
