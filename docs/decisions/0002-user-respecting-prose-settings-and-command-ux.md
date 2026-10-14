---
id: "0002"
title: "Apply Prose Settings Locally and Expose Workflow Through Named Commands"
status: "Accepted"
date: 2026-10-12
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1; commits 7f7b8dd, 44a2b7e, d01627b"
---

# 2. Apply Prose Settings Locally and Expose Workflow Through Named Commands

## Context and Problem Statement

Novelist should make supported prose buffers comfortable without unexpectedly changing unrelated buffers or imposing a writer's keybinding choices. The core behavior spans settings, setup lifecycle, filetype handling, and user-facing commands, so its opt-in/opt-out and interaction contract needs to remain consistent across those components.

The execution plan records the decision to apply settings automatically to Markdown and plain-text buffers, use local options, support global and per-buffer opt-outs, and provide named commands without default keymaps. It also specifies visual wrapping (`textwidth=0`) rather than inserting hard line breaks into saved text.

## Decision Drivers

- Avoid changing global editor behavior or modifying draft text as a side effect.
- Make behavior predictable for supported buffers and easy to disable.
- Avoid conflicts with user-defined mappings and established writing workflows.
- Keep the public interaction surface explicit and documentable.

## Considered Options

1. Set global prose options and provide default keymaps for the cockpit.
2. Apply configurable local options to supported buffers, provide opt-outs, and expose named commands without mappings.
3. Require users to configure every prose buffer and define all commands/mappings themselves.

## Decision Outcome

Chosen option: **apply configurable prose options locally to supported buffers, provide global and buffer-level opt-outs, and expose cockpit actions as named commands with no default keymaps.** Visual wrapping is used without hard-wrapping buffer contents.

## Consequences

- **Positive:** Unrelated buffers and global options are not intentionally reconfigured; users retain control over mappings and can disable the preset.
- **Positive:** Named commands work without choosing a mapping convention on behalf of users.
- **Negative:** Users who want automatic mappings or hard-wrapped text must configure those preferences separately.
- **Negative:** Automatic settings depend on supported filetype detection and the buffer lifecycle, so the opt-out must be set before settings are applied.

## Validation & Compliance

The plan's decisions and Task 2.1 / Task 3.1 acceptance criteria specify local settings, opt-outs, no default mappings, and command behavior. The implementation is in `lua/novelist/settings.lua`, `lua/novelist/init.lua`, and `lua/novelist/commands.lua`; integration tests cover settings lifecycle and absence of keymaps. Commits: `7f7b8dd`, `44a2b7e`, and `d01627b`. The state report records 22 passing tests on Neovim 0.11.6. Neovim 0.12+ manual smoke validation remains outstanding.
