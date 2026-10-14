---
id: "0001"
title: "Keep the Plugin Dependency-Free and Separate Parsing from Neovim Integration"
status: "Accepted"
date: 2026-10-12
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1; commits 7f7b8dd, a4cabb5, 44a2b7e"
---

# 1. Keep the Plugin Dependency-Free and Separate Parsing from Neovim Integration

## Context and Problem Statement

Novelist needs both prose-oriented editing features and a revision cockpit, but it had no existing implementation or dependency conventions. The project needed a low-friction plugin that works without requiring users to install a testing framework, Tree-sitter parser, or other runtime plugin. Its heading, count, and marker rules also needed to be testable without coupling their behavior to Neovim's UI and lifecycle APIs.

The plan explicitly selected standalone Lua, no required third-party dependencies, and simple buffer-line parsing. The implementation reflects this split in `lua/novelist/cockpit.lua` for line-based parsing and `lua/novelist/commands.lua` / `lua/novelist/init.lua` for editor integration.

## Decision Drivers

- Keep installation and runtime use independent of third-party plugins.
- Make text parsing deterministic and independently unit-testable.
- Keep editor lifecycle and UI concerns at a clear integration boundary.
- Avoid requiring Tree-sitter for a deliberately small Markdown/plain-text MVP.

## Considered Options

1. Require Tree-sitter or another parser/runtime dependency for headings and markers.
2. Implement parsing as pure Lua over arrays of buffer lines, and keep Neovim commands and lifecycle in integration modules.
3. Mix parsing, buffer reads, UI, and command registration in one module.

## Decision Outcome

Chosen option: **pure Lua line parsing with a separate Neovim integration layer, and no required third-party runtime dependencies.** This keeps the MVP installable in a minimal Neovim setup and allows the parsing contract to be exercised through dependency-free tests.

## Consequences

- **Positive:** No required plugin dependencies; simple headless test execution; parser behavior is isolated from UI and editor lifecycle.
- **Positive:** The architecture provides a stable place to add future parsing features without requiring them to own command registration.
- **Negative:** The lightweight parser intentionally supports only its documented heading and standalone-marker syntax; it is not a full Markdown parser and does not infer narrative structure.
- **Negative:** If richer syntax semantics become necessary, the parsing boundary may need an optional parser integration or a deliberate replacement.

## Validation & Compliance

The plan's Task 2.2 defines pure parsing over line arrays, and Task 3.1 assigns editor integration separately. `lua/novelist/cockpit.lua`, the command/setup modules, and dependency-free tests implement that boundary. Commit evidence: `7f7b8dd` (settings), `a4cabb5` (cockpit parsing), and `44a2b7e` (integration). The recorded suite passed 22 tests on Neovim 0.11.6; the plan's Neovim 0.12+ manual smoke validation remains outstanding and is not claimed as passed.
