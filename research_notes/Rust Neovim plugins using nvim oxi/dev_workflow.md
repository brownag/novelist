# nvim-oxi Plugin Development Workflow: Build, Test, Async, Distribution (state as of Oct 2026)

Method note: Most findings come from a shallow clone of `noib3/nvim-oxi` at `main` HEAD `7ad27a7` (last push 2026-05-17), the crates.io API, the GitHub issues/PRs API, and clones of real plugin repos (`dox4/taohua.nvim`, `strottos/nvim_oxi_template`, `Saghen/blink.cmp`). Permalinks below point to `main`; line contents may drift. I found no Reddit or Discourse threads from 2025-2026 about nvim-oxi workflow, so community-sentiment claims are thin.

**Version status to keep in mind throughout:**
- The latest **published** crate is `nvim-oxi 0.6.0`, released **2025-05-23**. Its features are `neovim-0-10`, `neovim-0-11`, `neovim-nightly`, `libuv`, `mlua`, `test`, `test-terminator` and `__vendored_luajit`. No release has followed in about 17 months. — [crates.io API](https://crates.io/api/v1/crates/nvim-oxi/versions); [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- Unreleased `main` differs from 0.6.0 in four ways:
  - Edition 2024, with `rust-version = "1.91.0"`.
  - Features `neovim-0-11`, `neovim-0-12` and `neovim-nightly`.
  - `neovim-0-10` was dropped (PR #302, merged 2026-04-06).
  - `neovim-0-12` was added (PR #295, merged 2026-04-06).
  - Sources: [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml); [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
- In practice, anyone targeting Neovim 0.12 in Oct 2026 must use a **git dependency on `main`**. crates.io 0.6.0 has no `neovim-0-12` feature (see crates.io API above).

---

## 1. Project setup (Cargo.toml, features, toolchain, platform flags, artifact naming)

### Takeaway
A plugin is a `cdylib` crate with exactly one Neovim-version feature enabled and a `#[nvim_oxi::plugin]` entry function. That function must have the same name as the library, because it generates `luaopen_<fn_name>`. You also need platform linker flags in `.cargo/config.toml`: on macOS so Neovim's symbols resolve at load time, and on Windows `/FORCE:MULTIPLE`. Finally, the built `lib<name>.so`/`.dylib`/`<name>.dll` must be renamed or placed so that Lua's `require` finds it, either under `lua/` on the runtimepath or via `package.cpath`.

### Cited Findings
- Recommended crate setup: `cargo new --lib`, then `[lib] crate-type = ["cdylib"]` and the `nvim-oxi` dependency. The examples README still says `nvim-oxi = "0.3"`, so that doc is stale. — [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- The entry point is `#[nvim_oxi::plugin] fn foo() -> T`. The macro emits `#[unsafe(no_mangle)] unsafe extern "C" fn luaopen_<fn_name>(state) -> c_int`, which calls `entrypoint`. That function initialises the arena, then `luajit::init(lua_state)`, then `libuv::init` if the feature is enabled, and finally pushes the return value onto the Lua stack. — [crates/macros/src/plugin.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/macros/src/plugin.rs); [src/entrypoint.rs](https://github.com/noib3/nvim-oxi/blob/main/src/entrypoint.rs)
- **Pitfall:** On Windows, a mismatch between the function name and the library name gives `E5108: The specified procedure could not be found`. The fix is to make the `#[nvim_oxi::plugin]` function name match the package/lib name. — [issue #185](https://github.com/noib3/nvim-oxi/issues/185)
- **Exactly one version feature is required.** The `build.rs` on `main` raises a `compile_error!` unless one of `neovim-0-11`, `neovim-0-12` or `neovim-nightly` is enabled. The features are cumulative (`neovim-0-12 = ["neovim-0-11", ...]`, `neovim-nightly = ["neovim-0-12", ...]`). — [build.rs](https://github.com/noib3/nvim-oxi/blob/main/build.rs); [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- The maintainer says the Neovim version you compile for is `max(neovim-*)`, so `["neovim-0-10", "neovim-nightly"]` is the same as `["neovim-nightly"]`. — [issue #234 comment by noib3](https://github.com/noib3/nvim-oxi/issues/234)
- Optional features on `main`:
  - `libuv` (event-loop handles)
  - `mlua` (enables `mlua` 0.11 with `luajit`, plus `mlua/module` via the default `__no_docsrs` feature)
  - `test` (the `#[nvim_oxi::test]` macro plus `cargo_metadata`)
  - `test-terminator` (implies `test` and `libuv`; for async tests)
  - Serde support is always on (`types` has `features = ["serde"]`).
  - Source: [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- **Toolchain:**
  - `main` declares `rust-version = "1.91.0"` and `edition = "2024"`, and CI installs the MSRV. — [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml); [ci.yaml](https://github.com/noib3/nvim-oxi/blob/main/.github/workflows/ci.yaml)
  - The MSRV was bumped to 1.88 in PR #293 (April 2026) and then to 1.91 in the HEAD commit. — [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
  - Building 0.6.0 with an old rustc failed (`str::from_utf8` not found in `nvim-oxi-types 0.6.0`). Updating the toolchain fixed it. — [issue #270](https://github.com/noib3/nvim-oxi/issues/270)
- **`.cargo/config.toml` used by nvim-oxi itself (main):**
  ```toml
  [target.x86_64-apple-darwin]
  rustflags = ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"]
  [target.aarch64-apple-darwin]
  rustflags = ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"]
  [target.x86_64-pc-windows-msvc]
  rustflags = ["-C", "link-args=/FORCE:MULTIPLE"]
  [target.aarch64-pc-windows-msvc]
  rustflags = ["-C", "link-args=/FORCE:MULTIPLE"]
  ```
  The macOS flags tell the linker that Neovim's FFI symbols will only be available at runtime. — [.cargo/config.toml](https://github.com/noib3/nvim-oxi/blob/main/.cargo/config.toml); [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- **Windows pain points:**
  - The maintainer points users with Windows linking errors (`LNK1181: cannot open input file 'lua5.1.lib'` when the `mlua` feature is on) to this config.toml. One user reported it still failed after `cargo clean`. — [issue #258](https://github.com/noib3/nvim-oxi/issues/258)
  - With `libuv` on, Windows ARM64 linking fails. One user worked around it with `"-C", "link-arg=/FORCE:UNRESOLVED"`.
  - The maintainer says libuv isn't tested on Windows: "I couldn't figure out the correct incantations and I don't have access to a Windows machine". — [issue #234](https://github.com/noib3/nvim-oxi/issues/234)
  - nvim-oxi's own test crate compiles out libuv tests on Windows (`// Libuv bindings don't work on Windows.`). — [tests/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/tests/src/lib.rs); [tests/Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/tests/Cargo.toml)
- **Android/Termux:** With `libuv`, loading fails with `dlopen failed: cannot locate symbol "luv_loop"`. The maintainer was unsure of the right linker flags for Android. — [issue #249](https://github.com/noib3/nvim-oxi/issues/249)
  - blink.cmp (an mlua-based plugin, not nvim-oxi) uses these flags for `aarch64-linux-android`: `linker=aarch64-linux-android-clang`, `link-args=-rdynamic` and `default-linker-libraries`. For musl Linux targets it uses `-C target-feature=-crt-static`. — [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml)
- **Artifact naming and placement:**
  - Cargo produces `libfoo.so` (Linux), `libfoo.dylib` (macOS) or `foo.dll` (Windows).
  - Rename to `lua/foo.so` on Linux and macOS (yes, `.so` on macOS), or `lua/foo.dll` on Windows.
  - Then add the parent of `lua/` to `runtimepath`, and `require("foo")` returns the value from the entry function.
  - Source: [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- **Alternative to renaming: extend `package.cpath` to point into `target/release`.**
  - taohua.nvim's `plugin/taohua.lua` appends `<root>/target/release/?<ext>` and `<root>/target/release/lib?<ext>` to `package.cpath`. It uses `jit.os` to pick `.dylib`, `.dll` or `.so` (its comment says this was "copied from blink.cmp"). — [taohua.nvim plugin/taohua.lua](https://github.com/dox4/taohua.nvim/blob/main/plugin/taohua.lua)
  - strottos' template looks in `target/release`, then `target/debug`, for `lib<name>.<ext>`, appends that path to `package.cpath`, and `pcall(require, ...)`s it with a helpful error if it's missing. — [nvim_oxi_template init.lua](https://github.com/strottos/nvim_oxi_template/blob/main/lua/nvim_oxi_template/init.lua)
- Example real-world Cargo.toml (taohua.nvim, 2026): `nvim-oxi = { version = "0.6.0", features = ["neovim-0-11", "test"] }`, `edition = "2024"`, `crate-type = ["cdylib"]`. — [taohua.nvim Cargo.toml](https://github.com/dox4/taohua.nvim/blob/main/Cargo.toml)
- crates.io lists only 5 published reverse dependencies of nvim-oxi (`just_nvim`, `umasi`, `tane`, `narabi`, `shikake`). Plugins are usually not published to crates.io. — [crates.io reverse deps API](https://crates.io/api/v1/crates/nvim-oxi/reverse_dependencies)

### Inferences
- Choose the version feature to match the *oldest* Neovim you support. Keyset/struct layouts are compiled in, so a binary built for one version's layout can misbehave on another (see Section 5). If you support both 0.11 and 0.12, you probably need either separate builds per Neovim minor or to restrict yourself to APIs whose layouts didn't change.
- The `package.cpath` approach (no copying) is simplest for "build on install" workflows. The rename-into-`lua/` approach is better for prebuilt-binary downloads.
- Because `luaopen_<name>` is derived from the function name, the module name you `require` must equal both the entry function name and the file stem.

### Gaps
- I couldn't verify whether `/FORCE:MULTIPLE` alone fixes the Windows libuv link failure. Issue #234 suggests `/FORCE:UNRESOLVED` was needed on ARM64, and the issue is still open.
- I found no official Android or FreeBSD guidance for nvim-oxi.
- No release date for 0.7.0 / the next version was announced in the sources I checked.

---

## 2. Plugin manager integration and distribution

### Takeaway
No nvim-oxi-specific installer exists. The common pattern is lazy.nvim `build = "cargo build --release"` (or `build = "make"`), plus Lua glue that finds the library in `target/release` via `package.cpath`. Production-grade distribution (prebuilt binaries per target triple, downloaded from GitHub Releases with checksums and a source-build fallback) is best modeled on blink.cmp, which is mlua-based but uses the identical cdylib mechanics. LuaRocks/Lux have a `rust-mlua` build backend that just runs cargo and copies the cdylib. It should work for nvim-oxi crates too, but I found no nvim-oxi plugin using it.

### Cited Findings
- **lazy.nvim build hooks:**
  - `build` can be a Lua function, a `*.lua` build file, a `:Command`, or any other string, which is run as a shell command. A list of steps is also allowed.
  - Builds run in parallel, so the docs advise against changing the cwd inside a build function.
  - Source: [lazy.nvim developers docs](https://lazy.folke.io/developers)
- Real usage examples:
  - taohua.nvim README: `{ "dox4/taohua.nvim", build = "make" }`, with the comment "use cargo build --release on Windows without make". Its Makefile's default target runs `cargo build --release`. — [taohua.nvim README/Makefile](https://github.com/dox4/taohua.nvim)
  - strottos' template test config uses lazy.nvim with `dir = plugin_root, build = "cargo build --release"`. — [nvim_oxi_template test/config/lazy-init.lua](https://github.com/strottos/nvim_oxi_template/blob/main/test/config/lazy-init.lua)
- **A question that comes up:** can lazy.nvim's `opts = {...}` auto-load an nvim-oxi plugin? Issue #183 asked this and was closed. The standard approach is a Lua `setup(opts)` wrapper module that `require`s the Rust lib (as in strottos' template, `M.setup(opts)` → `load_rust_lib()` → `rustlib.example(opts)`). — [issue #183](https://github.com/noib3/nvim-oxi/issues/183); [template init.lua](https://github.com/strottos/nvim_oxi_template/blob/main/lua/nvim_oxi_template/init.lua)
- **Prebuilt binaries: blink.cmp's model.** Its Rust fuzzy matcher is mlua-based (`mlua = { version = "0.11.3", features = ["module","luajit"] }`), but it is a cdylib like an nvim-oxi plugin.
  - Prebuilt binaries are attached to GitHub releases and downloaded automatically when the user is on a release tag (e.g. lazy.nvim `version = '1.*'`).
  - `fuzzy.prebuilt_binaries.force_version` forces a version when tracking `main`.
  - Manual install places the file at `$data/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.$ext`.
  - `fuzzy.implementation` picks between Rust and a Lua fallback (`prefer_rust_with_warning`, `prefer_rust`, `rust`, `lua`).
  - Building from source is also supported (`cargo build --release` or `nix run .#build-plugin`).
  - Source: [blink.cmp fuzzy docs](https://cmp.saghen.dev/configuration/fuzzy)
- **blink.cmp release workflow** (on tag `v*`):
  - Linux targets (glibc and musl, x86_64, aarch64, loongarch64), Android aarch64 and FreeBSD are built with `cross build --release --target <triple>`. aarch64 FreeBSD uses nightly `-Z build-std`.
  - macOS builds use `MACOSX_DEPLOYMENT_TARGET="13" cargo build --release --target ...`.
  - Windows builds use plain `cargo build` for x86_64 and aarch64 msvc.
  - OpenBSD is built separately.
  - Each artifact is renamed to `<triple>.<ext>`, a `.sha256` file is generated per file with `sha256sum`, and everything is uploaded via `softprops/action-gh-release`.
  - The release profile uses `lto = true, codegen-units = 1`.
  - Source: [blink.cmp release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml); [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml)
- **luarocks-build-rust-mlua:**
  - The rockspec uses `build = { type = "rust-mlua", modules = { ["my_module"] = "my_module" } }`. The native library is expected at `<target_path>/release/lib<name>.so` (OS-dependent).
  - Options: `target_path`, `default_features`, `features`, `cargo_extra_args` (e.g. `--locked`) and `include` (to copy extra Lua files).
  - The README has no notes on Neovim or non-mlua crates.
  - Source: [luarocks-build-rust-mlua](https://github.com/mlua-rs/luarocks-build-rust-mlua)
- **Lux** (the Rust-based LuaRocks successor) has a built-in `rust-mlua` build spec and a `lux.toml` project file. It describes itself as a work in progress. rocks.nvim is described as planning a rewrite onto Lux. `lux-cli` 0.39.x is on docs.rs. — [lux-cli on docs.rs](https://docs.rs/crate/lux-cli/0.39.7); [lib.rs lux-cli](https://lib.rs/crates/lux-cli)

### Inferences
- A practical recommended ladder for an nvim-oxi plugin in Oct 2026:
  1. Ship Lua glue that looks for the library in a known location (e.g. `target/release` or a downloaded `lua/<name>.so`) and errors clearly or falls back if it's missing.
  2. Support `build = "cargo build --release"` for users with a Rust toolchain.
  3. For broad reach, copy blink.cmp's release matrix and checksum approach and download by target triple in a Lua `build` function. Detect the triple via `jit.os`/`jit.arch` plus a glibc/musl check.
- Cross-compilation for nvim-oxi is easier than for typical C-linking crates. The cdylib links against nothing at build time on Linux (Neovim symbols resolve at dlopen), so `cross` or `cargo-zigbuild` should work like they do for blink.cmp. macOS still needs the `dynamic_lookup` flags, and Windows needs the `/FORCE` flags.
- Prebuilt binaries interact badly with the version-feature problem (Section 5). You may need to publish per-Neovim-minor builds (e.g. `x86_64-unknown-linux-gnu-nvim0.12.so`) or pin a minimum Neovim version. blink.cmp avoids this because mlua uses only the stable Lua C API, not Neovim's keyset structs.
- The `rust-mlua` rockspec backend only runs cargo and copies the library. It should work with an nvim-oxi crate as long as the module name matches the `luaopen_` symbol, and macOS flags come from the crate's `.cargo/config.toml`. This is untested by me.

### Gaps
- I found no nvim-oxi plugin that ships prebuilt binaries via GitHub Releases, or any using luarocks/rocks.nvim/Lux, to confirm these paths end-to-end.
- I couldn't fetch blink.cmp's current downloader Lua source (the file layout has changed), so I didn't confirm how it detects the target triple and verifies checksums.
- packer.nvim is unmaintained (archived in 2023, per general knowledge; not re-verified here). Its `run = "cargo build --release"` hook is analogous, but I didn't look it up.

---

## 3. Testing (`#[nvim_oxi::test]`, the `test` feature, CI)

### Takeaway
Enable the `test` feature and put integration tests in a separate `cdylib` crate whose `build.rs` calls `nvim_oxi::tests::build()`. Each `#[nvim_oxi::test] fn` is compiled into its own Lua entrypoint. A normal `#[test]` wrapper spawns a headless `nvim` (found on `$PATH`) that `package.loadlib`s the test library and runs it, then reads the pass/fail result from stderr. CI then needs only Rust plus Neovim installed per matrix entry, e.g. via `rhysd/action-setup-vim`.

### Cited Findings
- **Rules for `#[nvim_oxi::test]`:**
  - The `test` feature provides the macro, and tests run inside a spawned `nvim` found on `$PATH`.
  - Test function names must be unique across the crate, even across modules.
  - Integration tests must live in a separate `cdylib` crate with a `build.rs` that calls `nvim_oxi::tests::build()`.
  - Source: [nvim-oxi README](https://github.com/noib3/nvim-oxi)
- **What the macro generates:**
  - A `#[test] fn <name>()` that calls `test_body(env!("CARGO_MANIFEST_PATH"), "__<name>", extra_cmd)`.
  - A hidden `#[nvim_oxi::plugin] fn __<name>()` wrapping your body.
  - Test functions may return `Result<(), E: Debug>`.
  - `#[should_panic]` is supported.
  - It accepts a `cmd = "..."` attribute (an extra Ex command to run first; multi-line is joined with `;`) and a `nvim_oxi = path` attribute for re-exports.
  - Source: [crates/macros/src/test.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/macros/src/test.rs); [CHANGELOG 0.5.0](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- **How Neovim is spawned:**
  - The exact command is `nvim -u NONE --headless -i NONE -c "set noswapfile" [-c <cmd>] -c "lua local f = package.loadlib([[<library_path>]], 'luaopen___<name>'); f()"`.
  - Inside Neovim, the plugin body installs a panic hook and runs the test under `catch_unwind`. It writes a fenced result (`__NVIM_OXI_TEST_RESULT_START__...END__`) to stderr, then runs `qall!` on pass or `cquit 1` on failure.
  - The host side parses stderr and re-raises the panic with the original location.
  - If Neovim died without a result, the test reports `Neovim segfaulted` or `Neovim exited with code N`.
  - Source: [src/tests/test_macro.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/test_macro.rs)
- **`tests::build()`:**
  - It must run inside a build script. It uses a `NVIM_OXI_BUILDING_TESTS` env-var guard to avoid recursion.
  - It re-invokes cargo to build the test crate as a cdylib with the same profile and enabled features, and exports the profile via `cargo:rustc-env`.
  - It sets `rerun-if-changed` on the library path.
  - If the library is missing at test time, you get the error "couldn't find library at '...'. Did you forget to use the build script?"
  - Source: [src/tests/build.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/build.rs); [test_macro.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/test_macro.rs)
- **nvim-oxi's own test crate:**
  - `[lib] crate-type = ["cdylib"]` with features forwarding `neovim-0-11`/`0-12`/`nightly`.
  - `nvim-oxi = { path = "..", features = ["libuv","mlua","test"] }`, minus `libuv` on Windows.
  - `[build-dependencies] nvim-oxi = { features = ["test"] }`.
  - `build.rs`: `fn main() -> Result<(), nvim_oxi::tests::BuildError> { nvim_oxi::tests::build() }`.
  - Sources: [tests/Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/tests/Cargo.toml); [tests/build.rs](https://github.com/noib3/nvim-oxi/blob/main/tests/build.rs)
- **Async tests: `test-terminator`.** The test fn can take a `TestTerminator` argument. The test keeps running after the plugin is `require`d until `terminator.terminate(Ok(()) | Err(TestFailure::Error(e) | TestFailure::Panic(info)))` is called; this is implemented with an `AsyncHandle`. "If the `TestTerminator` is dropped without first calling `terminate`, the test will run forever." — [src/tests/terminator.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/terminator.rs)
- **Known testing limitations:**
  - An AsyncHandle test is `#[ignore = "the callback is never called"]`, with the TODO "how do we wait for the callback to be executed without blocking the main thread?" — [tests/src/libuv/async_handle.rs](https://github.com/noib3/nvim-oxi/blob/main/tests/src/libuv/async_handle.rs)
  - A user reports that `api::command("sleep 2")?` works for waiting in async tests. — [issue #271](https://github.com/noib3/nvim-oxi/issues/271)
  - An open PR (#289, Jan 2026) is titled "Fix library path in test build script". — [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
- **nvim-oxi's CI (template for plugin CI):**
  - Matrix `os: [ubuntu-latest, macos-latest, windows-latest]` × `neovim: [v0.11.7, v0.12.0, Nightly]`, mapping each to `--features neovim-0-11|neovim-0-12|neovim-nightly`.
  - Neovim is installed with `rhysd/action-setup-vim@v1` (`neovim: true, version: ...`), then `cargo test --workspace <features>` runs.
  - Separate clippy (`--features neovim-nightly,libuv,mlua,test,test-terminator -D warnings`), docs (nightly, `--cfg docsrs`) and fmt jobs.
  - A daily cron run catches Nightly breakage.
  - Source: [.github/workflows/ci.yaml](https://github.com/noib3/nvim-oxi/blob/main/.github/workflows/ci.yaml)
- **Alternative harness without the macro** (taohua.nvim):
  - A plain Rust `#[test]` spawns `nvim --headless -u NORC --cmd "set rtp^=<cwd>" -l tests/run_test.lua <case> <cwd>` against a pre-built release library (`make test` runs `cargo build --release` first) and compares against expected Lua fixtures.
  - Its CI installs Neovim v0.10.0 via `rhysd/action-setup-vim@v1.6.1`, although the crate enables `neovim-0-11`. That looks like a latent version mismatch.
  - Sources: [taohua.nvim tests/headless.rs](https://github.com/dox4/taohua.nvim/blob/main/tests/headless.rs); [makefile.yml](https://github.com/dox4/taohua.nvim/blob/main/.github/workflows/makefile.yml)

### Inferences
- Because every test is a fresh `nvim -u NONE` process, tests are isolated but slower than in-process tests, and no user config or other plugins are loaded. Use the `cmd` attribute to set up `rtp` or options when a test needs them.
- Pure-logic Rust code should be factored into a normal `rlib` module/crate with ordinary `cargo test`. Reserve `#[nvim_oxi::test]` for code that touches the API.
- Plugin CI should mirror nvim-oxi's matrix and map each Neovim version to the matching feature flag. Testing a binary built for one feature against another Neovim minor is exactly how layout bugs (Section 5) surface.

### Gaps
- I found no third-party test-harness crate specifically for nvim-oxi beyond the built-in `test` feature. Lua-side tools like busted/mini.test/plenary can test the Lua wrapper layer, but I didn't verify any nvim-oxi project combining them.

---

## 4. Async: libuv handles, tokio in background threads, thread safety

### Takeaway
All Neovim API calls must happen on the main thread. The only sanctioned cross-thread primitive is `nvim_oxi::libuv::AsyncHandle`, which is `Send + Sync` and must be created on the main thread. Its callback always runs on the main thread. The canonical pattern is: run tokio (or anything else) on a `std::thread`, send data through a channel, call `handle.send()` to wake Neovim, then drain the channel in the callback (optionally inside `schedule`). nvim-oxi has no async executor integration. A safer token-based API was discussed but not implemented.

### Cited Findings
- **`AsyncHandle`:**
  - `AsyncHandle::new(callback)` "Registers a new callback on the Neovim event loop, returning an AsyncHandle which can be used to execute the callback from any thread. The callback will always be executed on the main thread."
  - The callback is `FnMut() -> R + 'static`, where `R: IntoResult<()>`.
  - It carries `unsafe impl Send` and `unsafe impl Sync`.
  - Source: [crates/libuv/src/async.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/libuv/src/async.rs)
- **`TimerHandle`:** `TimerHandle::start(timeout, repeat, cb)` repeats with `|timer: &mut TimerHandle|` (it can call `timer.stop()`). `TimerHandle::once(timeout, cb)` fires once; a zero timeout fires on the next loop iteration. — [crates/libuv/src/timer.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/libuv/src/timer.rs)
- **Official tokio example** ([examples/libuv.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/libuv.rs)):
  - Creates a `tokio::sync::mpsc::unbounded_channel`.
  - `AsyncHandle::new(move || { let i = receiver.blocking_recv().unwrap(); schedule(move |_| print!(...)); })`.
  - `thread::spawn(move || send_numbers(handle, sender))`, where `send_numbers` is a `#[tokio::main] async fn` that loops `sender.send(i); handle.send(); time::sleep(1s).await`.
  - Inside timer callbacks the example also wraps API calls in `nvim_oxi::schedule(...)`.
- **Thread-safety contract (maintainer):** "The implicit API contract is that all free-standing functions exposed by this library should only be called from the main thread." Calling `nvim_oxi::api::*` off-thread "may not result in an immediate segfault, [but] opens up all sorts of potential race conditions". The maintainer considered threading a `&Neovim` token through the entrypoint but hasn't done so. — [issue #260, comment by noib3](https://github.com/noib3/nvim-oxi/issues/260)
- **Footgun:** Creating an `AsyncHandle` from a non-main thread crashes Neovim with no chance to recover.
  - A user built a `!Send` `MainThreadToken` typestate using a `OnceLock<ThreadId>` to guard this at compile time.
  - The user uses `tracing` for logging from the other thread.
  - Source: [issue #260](https://github.com/noib3/nvim-oxi/issues/260)
- A contributor working on "a similar library to nvim-oxi" says to "never call neovim's functions outside of callbacks and plugin entrypoints and never call neovim's functions from another thread". They note Neovim's C API has many undocumented traps ("they don't officially support the API yet"). — [issue #260, comment by airblast-dev](https://github.com/noib3/nvim-oxi/issues/260)
- **mlua `send` conflict:** mlua's `send` feature (needed to move `Lua` across threads in async code) conflicts with `mlua/module`, which nvim-oxi's `mlua` feature pulls in. One user dropped nvim-oxi's `mlua` feature and used mlua directly to get `send`. — [issue #286](https://github.com/noib3/nvim-oxi/issues/286)
- **libuv portability:** libuv-based features don't link or work on Windows (untested there), and fail on Android/Termux (`luv_loop` symbol missing). — [issue #234](https://github.com/noib3/nvim-oxi/issues/234); [issue #249](https://github.com/noib3/nvim-oxi/issues/249); [tests/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/tests/src/lib.rs)
- **Related crate:** `willothy/nvim-utils` is no longer maintained and points users to nvim-oxi. — [nvim-utils](https://github.com/willothy/nvim-utils)
- The libuv docs state that no other thread interacts with the event loop except through `uv_async_send`, which `AsyncHandle::send` wraps. — [libuv threads guide](https://docs.libuv.org/en/v1.x/_sources/guide/threads.rst.txt)

### Inferences
- Recommended architecture:
  1. Create every `AsyncHandle` and channel in the `#[plugin]` entrypoint or another main-thread callback.
  2. Keep a long-lived tokio `Runtime` in a background thread, stored in a `OnceLock` or kept alive by a spawned thread.
  3. Move only plain data (and the cloned `AsyncHandle`) to workers.
  4. In the callback, drain with `try_recv` in a loop rather than `blocking_recv`, because libuv coalesces multiple `send()`s into one callback. The official example's one-`blocking_recv`-per-callback pattern can lag or block the UI.
- Without the `libuv` feature, a fallback for Windows is polling from a Lua `vim.uv` timer. Another is having Lua own a `vim.uv.new_async` and calling into Rust. Neither is documented by nvim-oxi.
- Hold Neovim objects (`Buffer`, `Window`, `Function`) only on the main thread. They wrap handles and Lua registry refs that aren't thread-safe even if the type system allows moving them.

### Gaps
- I found no nvim-oxi-native async/await executor (e.g. a future-on-libuv bridge) in the crate. I couldn't identify the name of airblast-dev's alternative library because the GitHub API was rate-limited.
- I couldn't confirm whether the `libuv` feature works on macOS with Neovim 0.12 builds. CI runs on macOS, which suggests yes, but I didn't see run results.

---

## 5. Debugging and pitfalls

### Takeaway
The main failure mode is a hard Neovim crash or abort rather than a Lua error, for three reasons: (a) panics in callbacks cannot unwind across `extern "C"`; (b) returning `Err` from some callbacks or the entrypoint has crashed Neovim because of `lua_error` longjmp-ing over Rust frames; and (c) a struct-layout mismatch between the nvim-oxi version feature and the running Neovim version. You also cannot hot-reload a changed `.so` into a running Neovim, so restart Neovim to pick up rebuilds.

### Cited Findings
- **ABI/layout mismatch:**
  - Any `api::set_hl()` call from a plugin built with `neovim-0-12` aborts Neovim 0.12.2 with "panic in a function that cannot unwind". Cause: `SetHighlightOpts`'s `#[repr(C)]` layout is still pinned to Neovim 0.11.3's keyset, while 0.12 added 5 fields, reordered booleans and changed `cterm`.
  - Fix PRs #303/#312 were open as of June 2026.
  - Source: [issue #311](https://github.com/noib3/nvim-oxi/issues/311); [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
  - Other 0.12 layout fixes: `WindowOpts` (PR #301, merged), and autocmd `buffer`→`buf` (PR #307, WIP). — [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
  - Older example: `api::notify` crashed Neovim (`munmap_chunk(): invalid pointer`) because `NotifyOpts` was zero-sized and Neovim read past it. It was fixed on `main` in 2025, but a release had to wait because main carried breaking changes. — [issue #215](https://github.com/noib3/nvim-oxi/issues/215)
- **Errors crash Neovim:**
  - Returning `Err` from a `Function` callback (e.g. a serde deserialization error in the `mechanic` example), or from the plugin entrypoint, crashes Neovim.
  - A contributor suspects `lua_error`'s longjmp over Rust stack frames is unsound and also leaks. The workaround is to never return errors and report via `api::echo`/`notify` instead.
  - Source: [issue #231](https://github.com/noib3/nvim-oxi/issues/231)
  - PR #279 ("when error, return nil, not lua_error") is still open. PR #290 ("Fix: Error types returned by commands panic") is closed. — [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
- **Other panics:**
  - "Panic when getting keymaps" (#299) and "Panic Autocmd without Buffer" (#306) were open in April 2026.
  - `Window::call` appeared to panic, but the cause was passing `((),)` instead of `Array::new()` to `api::call_function`. Its arguments are not validated at compile time. — [issue #305](https://github.com/noib3/nvim-oxi/issues/305)
- **Panic handling:** The test harness explicitly uses `panic::set_hook` and `catch_unwind` (Section 3). I found no `catch_unwind` in the runtime crates (`grep` over `crates/luajit`, `crates/api` and `src/*.rs` on `main`), which is consistent with the "cannot unwind" aborts in #311. — [src/tests/test_macro.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/test_macro.rs); [issue #311](https://github.com/noib3/nvim-oxi/issues/311)
- **Logging:**
  - `nvim_oxi::print!` and `nvim_oxi::dbg!` are re-exported from the luajit crate and print to the message area, on the main thread only. — [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs)
  - A plugin author uses `tracing` for background-thread logging. — [issue #260](https://github.com/noib3/nvim-oxi/issues/260)
  - strottos' template sets `NVIM_LOG_FILE` to a project-local path and launches `nvim -u test/config/lazy-init.lua` after `cargo build` for a dev loop. — [nvim_oxi_template scripts/run.sh](https://github.com/strottos/nvim_oxi_template/blob/main/scripts/run.sh)
- The test harness distinguishes "Neovim segfaulted" (no exit code) from a non-zero exit. That makes crashes visible in CI instead of hanging. — [test_macro.rs](https://github.com/noib3/nvim-oxi/blob/main/src/tests/test_macro.rs)

### Inferences
- Defensive practices:
  - Wrap every exported closure body in `std::panic::catch_unwind`.
  - Convert `Err` into a returned `nil`/`{ok=false, err=...}` table or a `vim.notify`, rather than returning `Err` to Lua (taohua.nvim's `{ ok = true, value } / { ok = false, error }` return shape follows this; see [taohua README](https://github.com/dox4/taohua.nvim)).
  - Build with `panic = "unwind"` (the default). Don't set `panic = "abort"` if you rely on `catch_unwind`.
- **Hot reload:**
  - LuaJIT's `package.loadlib`/`require` caches the C module, and the process keeps the dlopen'd library mapped. Clearing `package.loaded[name]` does not unload the old code.
  - Overwriting the `.so` in place while Neovim has it mapped can crash Neovim on Linux.
  - The practical dev loop: `cargo build` → restart Neovim (or run a headless `nvim -l` script / `#[nvim_oxi::test]`). If you install new builds, write to a new file and rename it, rather than truncating the mapped file.
  - This is standard dlopen/LuaJIT behavior inferred from general knowledge. I didn't find an nvim-oxi-specific source.
- Use `RUST_BACKTRACE=1` when launching `nvim` to get Rust backtraces on panic. Issue #305's reporter got a symbolised backtrace this way, though the env var isn't named in the issue.
- To debug segfaults, run `gdb --args nvim ...` or `lldb -- nvim` against a debug build. Layout mismatches typically show up as crashes inside Neovim's `api/` functions.

### Gaps
- No official nvim-oxi documentation on debugging, logging or hot reload was found.
- I couldn't confirm whether PR #279 or #312 merged after June 2026. The repo's last push was 2026-05-17 per the GitHub API, and the PR list showed #312 open, so the `set_hl` crash on 0.12 is likely still present on `main` as of Oct 2026. Re-verify before relying on this.

---

## 6. Using mlua alongside nvim-oxi

### Takeaway
Enable `features = ["mlua"]` and call `nvim_oxi::mlua::lua()` to get an `mlua::Lua` bound to Neovim's own Lua state. Use it as an escape hatch for things nvim-oxi's typed API lacks, such as arbitrary `vim.*` Lua functions, `vim.fn` (which nvim-oxi doesn't wrap yet), or calling other plugins' Lua modules. The integration is thin, and its forced `mlua/module` feature blocks mlua's `send` feature.

### Cited Findings
- `nvim_oxi::mlua::lua()` is implemented as `luajit::with_state(|lua_state| mlua::Lua::get_or_init_from_ptr(lua_state as *mut _).clone())`. That is, it wraps Neovim's existing `lua_State`. — [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs)
- Example: `let lua = mlua::lua(); let print: LuaFunction = lua.globals().get("print")?; print.call::<()>("..")?;`. — [examples/mlua.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/mlua.rs)
- On `main`, the `mlua` feature pulls `mlua = { version = "0.11", features = ["luajit"] }`, plus `mlua/module` through the default `__no_docsrs` feature (`vendored` for docs.rs). — [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- Issue #286 asks whether `mlua/module` is needed at all, since nvim-oxi does its own module creation. It conflicts with mlua's `send`. A contributor's tests (PR #288) pass without it. A draft PR #308 ("Add mlua as a core dependency feature", May 2026) was closed. — [issue #286](https://github.com/noib3/nvim-oxi/issues/286); [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr)
- On Windows, the `mlua` feature produced `LNK1181: cannot open input file 'lua5.1.lib'`, while plain `mlua` with `luajit` compiled. — [issue #258](https://github.com/noib3/nvim-oxi/issues/258)
- `vim.fn` bindings are not yet in nvim-oxi (PR #314 "Add vimscript function bindings", open June 2026). A maintainer-contributor said they hoped to add a `vim.fn` equivalent. — [PR list](https://github.com/noib3/nvim-oxi/pulls?q=is%3Apr); [issue #305 comment](https://github.com/noib3/nvim-oxi/issues/305)
- 1:1 mlua-version coupling: nvim-oxi `main` pins mlua 0.11. Issue #249's user had a separate `mlua = "0.10.5"` alongside `nvim-oxi 0.6.0` with `mlua` enabled. — [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml); [issue #249](https://github.com/noib3/nvim-oxi/issues/249)

### Inferences
- Use mlua when you need:
  - Dynamic Lua interop (calling `vim.lsp.*`, `vim.treesitter`, other plugins).
  - Userdata with methods exposed to Lua.
  - Async Lua functions (mlua's `async` feature).
- Use nvim-oxi's typed `api::*` for core editor operations: performance (direct C calls, no Lua round-trip) and compile-time types.
- If you also depend on `mlua` directly, match nvim-oxi's mlua version (0.11 on `main`) to avoid two mlua copies with separate state registries.
- If you need mlua's `send`, the current workaround from #286 is to skip nvim-oxi's `mlua` feature and construct `mlua::Lua` yourself from the state pointer. Do this only on the main thread.
- If a plugin is mostly Lua interop and doesn't need Neovim's C API, plain mlua with `module`, as blink.cmp does ([blink.cmp](https://cmp.saghen.dev/configuration/fuzzy)), avoids nvim-oxi's per-Neovim-version layout coupling entirely. That is a serious distribution advantage for prebuilt binaries.

### Gaps
- I found no benchmarks comparing nvim-oxi's direct API calls with mlua calls to `vim.api`.
- It's unclear whether `nvim_oxi::mlua::lua()` is safe to call from callbacks triggered by `AsyncHandle` and timers. It should be, since they run on the main thread, but this isn't documented.
