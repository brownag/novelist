# Appendix B — Shipping an mlua plugin, failure modes, and alternatives

Read after Appendix A, before the first release of a plugin with a Rust module. The engineering effort in a Rust Neovim plugin is mostly here, not in the Rust code. Practices are drawn from blink.cmp / blink.lib, fff.nvim, avante.nvim and luarocks-build-rust-mlua as of October 2026; none of this section was executed locally, and the ecosystem hasn't settled on one answer for several choices — pick deliberately and document it.

## Contents

1. How users get the binary
2. Platform matrix and CI
3. Matching the binary to the Lua code
4. Replacing a binary that can't be unloaded
5. Integrity
6. Failure table
7. mlua vs nvim-oxi vs RPC

---

## 1. How users get the binary

Offer both, with prebuilt as the default:

- **Prebuilt download**: CI attaches one asset per target triple to each GitHub Release, named `<triple>.<ext>` (e.g. `x86_64-unknown-linux-gnu.so`, `aarch64-apple-darwin.dylib`, `x86_64-pc-windows-msvc.dll`). A Lua `download()` function, triggered by the plugin manager's build hook, fetches the right one with `curl` via `vim.system`.
- **Build from source**: `cargo build --release` as a build hook or `:MyPlugin build` command, for unsupported platforms, Nix users and contributors.

Plugin-manager hooks: lazy.nvim `build = function() require('myplugin.native').download():wait() end` (or `build = 'cargo build --release'`); vim.pack (0.12 built-in) users run the same function from a `PackChanged` autocmd. Make the function **synchronous-waitable** — blink.lib returns a task the hook can `:pwait()` — so the install doesn't finish before the binary exists.

Other channels: **LuaRocks/rocks.nvim** via `luarocks-build-rust-mlua` (always compiles on the user's machine, needs cargo; maps the host Lua to the right mlua feature — this is how toml-edit.lua reaches rocks.nvim). **Nix**: a flake with `rustPlatform.buildRustPackage` (blink.cmp ships one).

Never make startup fail if the binary is missing: warn once (or via `:checkhealth`) and fall back.

## 2. Platform matrix and CI

blink.cmp's tag-triggered release builds ~13 targets: Linux glibc + musl on x86_64/aarch64 (+loongarch64), Android, FreeBSD, macOS x86_64 + arm64 (`MACOSX_DEPLOYMENT_TARGET=13`), Windows x86_64 + aarch64 MSVC. A practical minimum: Linux x86_64/aarch64 gnu, Linux x86_64 musl, macOS arm64/x86_64, Windows x86_64 msvc.

Tools in use:

- **`cross`** (Docker images, CentOS-based for old glibc) — blink.cmp.
- **`cargo zigbuild`** with a glibc-pinned target like `x86_64-unknown-linux-gnu.2.31` — fff.
- **Native runners** (ARM Linux, macOS, Windows) + `manylinux2014` container — avante.

**glibc baseline is an open question.** blink.cmp and avante target glibc 2.17; fff says Rust 1.91+ won't link for 2.17 and targets 2.31. Neither claim was verified here. Choose a baseline, test the artifact on an old distro container, and state the minimum in the README.

Per-target flags: musl needs `-C target-feature=-crt-static`; macOS needs the `build.rs` from Appendix A. Pin GitHub Actions by commit SHA. Publish a `.sha256` per asset.

## 3. Matching the binary to the Lua code

The Lua side and the Rust side change together, so a stale binary with newer Lua (or vice versa) produces "attempt to call a nil value" or worse. Strategies seen in the wild:

- **Version in the filename** (blink.lib): the 7-char git commit is part of the library name, so after an update the old binary simply isn't found and a download/build is triggered. Requires users to install from release tags.
- **Download for the current tag** (blink, fff): read the plugin's git tag and fetch that release. Breaks for users tracking `main` — blink asks users to pin a version; avante takes the opposite stance and always fetches the latest release, telling users never to pin. Pick one, and say so in the install docs.
- **Export a version function** from Rust (`m.version()`) and compare it with a Lua constant at load; on mismatch, refuse to use the binary and tell the user how to rebuild/download. Cheap and robust; works for source builds too.

## 4. Replacing a binary that can't be unloaded

A process can't unload a native library, and a second `package.loadlib` on the same path returns the already-loaded copy. So updates take effect only after a restart, and writing over a mapped file in place can crash the running editor.

- **Download to `<path>.tmp`**, validate it (`package.loadlib(tmp, 'luaopen_x')` — note this loads it into the process; fff does this), then **rename** into place. Rename replaces the directory entry; the running process keeps its mapping.
- **Windows** won't let you rename over a loaded DLL. Leave the verified `.tmp` and promote it at the next startup before loading (fff), or use a new filename per version (blink.lib) and delete old ones later (`.old.<random>` then unlink).
- Tell the user to `:restart` after an update. Load by absolute path (Appendix A §3) so `package.cpath` pollution can't load a different copy.

## 5. Integrity

Checksum verification has regressed in the ecosystem: blink.cmp v1 checked `.sha256` files (`sha256sum`/`shasum`/`certutil`), the current blink.lib downloader only checks that the library loads, fff and avante don't verify at all. You are downloading native code that runs inside the user's editor: **verify the sha256 published alongside the asset** before promoting the `.tmp` file, use HTTPS release URLs only, and fail closed (keep the old binary / fall back to Lua) on mismatch.

## 6. Failure table

| Symptom | Likely cause | Fix |
|---|---|---|
| `compile_error!` mentioning module mode | `vendored`, `send`, or two Lua features with `module` | `features = ["luajit", "module", ...]` only |
| macOS link errors for `_lua_*` | no `dynamic_lookup` | `build.rs` from Appendix A |
| `module 'x' not found` on macOS | `.dylib` isn't a `require` suffix | rename to `.so`, or `package.loadlib` by path |
| "undefined symbol luaopen_…" / "procedure could not be found" | `name =` doesn't match `require` path (dots→underscores); wrong arch | fix `name`; rebuild; `file`/`ldd`/`nm -D` the binary |
| `GLIBC_2.xx not found` | built on newer glibc than user's | older-glibc build (zigbuild pin / manylinux), or musl asset |
| musl (Alpine etc.): library fails to load | static CRT in the cdylib | `-C target-feature=-crt-static` |
| New Lua calls missing functions after update | stale binary still loaded/installed | version check (§3); `:restart` |
| Editor freezes | main thread blocked on worker lock; huge synchronous call | `try_lock`, snapshots, chunk work, poll |
| Editor dies silently | panic in own thread, `panic = "abort"`, `unsafe` UB | `catch_unwind` in workers, keep `unwind`, panic hook logging to `stdpath('log')` |
| `attempt to yield across C-call boundary` | calling an mlua `async` function directly | don't use `async`; threads + polling |
| `attempt to index a userdata value` on an error | mlua errors are userdata | `tostring(err)` |

## 7. mlua vs nvim-oxi vs RPC

| | mlua module | nvim-oxi | RPC process (nvim-rs) |
|---|---|---|---|
| Binary coupled to | LuaJIT 5.1 C API (frozen) — one build per platform | One Neovim minor version | msgpack-RPC API (versioned) |
| Editor API from Rust | Dynamic via `vim.*`, untyped | Typed `nvim_*` wrappers (gaps: lsp, treesitter, much of `vim.fn`) | Full generated API, `rmpv::Value` |
| In-process callbacks | Yes | Yes | No — Lua shim + `rpcnotify` |
| Background work | Threads + Lua polling | `libuv::AsyncHandle` can wake the loop | Native async (tokio/smol) |
| Errors | `Err`/callback panics → Lua errors | `Err` across the boundary has crashed Neovim | Process-isolated |
| Release state (Oct 2026) | 0.12.2 (Oct 2026), active | crates.io 0.6.0 (May 2025, Neovim ≤0.11); 0.12 support only on git main | 0.9.2; README calls API unstable |
| Users | blink.cmp, fff, avante, rocks.nvim | nomad | few |

Choose:

- **mlua** (default): Rust is a compute/data engine behind a Lua UI; you want binaries that survive Neovim upgrades.
- **nvim-oxi**: most logic must drive the editor API from Rust with compile-time types, and you accept per-Neovim-version builds and a pinned git dependency. (There's a separate earlier report on nvim-oxi in this repo's `reports/` if you need depth.)
- **RPC**: a crash must not take down the editor; the backend is a long-running service; or the same binary serves other editors. Keep it off per-keystroke paths (every call is an IPC round trip). Prefer a Lua shim that starts the process with `vim.system`/`jobstart` and talks over `vim.rpcrequest` over the legacy `:UpdateRemotePlugins` remote-plugin mechanism.
