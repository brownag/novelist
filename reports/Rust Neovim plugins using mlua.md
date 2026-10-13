# Ship Rust inside Neovim through mlua

The standard way to put Rust inside a Neovim plugin in October 2026 is to build a `cdylib` with **mlua 0.12 in `module` mode** (`features = ["luajit", "module"]`), export a `luaopen_<name>` entry point with `#[mlua::lua_module]`, and load the library from Lua with `require` or `package.loadlib`. Because the module runs on Neovim's own `lua_State`, Rust reaches the editor only through ordinary Lua values such as `vim.api.*`. As a result the binary depends only on LuaJIT's frozen Lua 5.1 C API, not on Neovim's internal structs. This one property explains why the largest Rust-backed plugins (blink.cmp, fff, avante.nvim, and toml-edit.lua for rocks.nvim) all use mlua and none of them use nvim-oxi. One binary per target triple works across Neovim releases, while an nvim-oxi binary is pinned to a single Neovim minor version and nvim-oxi has had no crates.io release since May 2025. The trade-offs are real, though. Editor API access from Rust is dynamic and untyped. mlua forbids its `send` feature in module mode, so Lua handles never leave the main thread. Its `async` support does not plug into Neovim's event loop. A crash in your code kills the editor. And the hardest engineering is not the Rust code but distribution: cross-compiling per platform, getting macOS and Windows linking right, keeping binary and Lua versions matched, and working around the fact that a loaded library can never be unloaded. The pattern production plugins have converged on is a pure Rust core crate, a thin mlua glue crate, and Lua that owns the UI, editor calls and loading.

## Four settings decide whether Neovim can load the module

**Pick features carefully, because several wrong choices are compile errors.** The current release is **mlua 0.12.2 (3 October 2026)**. It requires Rust 1.88 and edition 2024, and enables no features by default ([mlua Cargo.toml](https://github.com/mlua-rs/mlua/blob/main/Cargo.toml); [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)). For Neovim the dependency line is `mlua = { version = "0.12", features = ["luajit", "module"] }`, optionally plus a few more:

- `serde`, which replaced the deprecated `serialize`;
- `macros`, which is needed for `#[derive(UserData)]` and `#[derive(FromLua)]`;
- `anyhow`.

The `mlua-sys` build script enforces three rules ([main_inner.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main_inner.rs); [src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/src/lib.rs)):

- exactly one Lua-version feature must be enabled;
- **`vendored` and `module` are mutually exclusive**;
- **`send` is "not supported in module mode"**.

The `vendored` ban makes sense. A module must call the LuaJIT that is already running inside `nvim`, and a second statically linked VM operating on Neovim's `lua_State` would corrupt it. Use `luajit`, not `luajit52`. The `52` variant only toggles LuaJIT's Lua 5.2 compatibility build flag, and Neovim's bundled LuaJIT is built without it ([find_vendored.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/find_vendored.rs); [BuildLuajit.cmake](https://github.com/neovim/neovim/blob/master/cmake.deps/cmake/BuildLuajit.cmake)). Module builds need no Lua headers or libraries installed, because the `lua_*` symbols resolve from the host process at load time ([mlua README](https://github.com/mlua-rs/mlua)).

**The exported symbol name must match the module path.** `#[mlua::lua_module]` wraps `fn foo(lua: &Lua) -> LuaResult<T>` in a `#[unsafe(no_mangle)] extern "C-unwind" fn luaopen_foo`. `name = "x"` overrides the symbol name, but the value is parsed as a Rust identifier, so it cannot contain dots or dashes ([mlua_derive module.rs](https://github.com/mlua-rs/mlua/blob/main/mlua_derive/src/module.rs)). The return value can be any `IntoLua` type, though by convention it is a table of functions. One library may define several entry points, and returning `Err` makes `require` raise a Lua error ([tests/module](https://github.com/mlua-rs/mlua/blob/main/tests/module/src/lib.rs)). Neovim builds the symbol name it looks up by stripping everything up to the first `-` and turning dots into underscores. So `require("novelist.native")` looks for `luaopen_novelist_native` ([vim/loader.lua](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/loader.lua)). Add `skip_memory_check` as well. It turns off protected-mode allocation checks, which are of little use under Neovim's unlimited LuaJIT heap. blink.cmp's source notes that it "greatly improves performance", and fff cites the same reason ([docs.rs lua_module](https://docs.rs/mlua/latest/mlua/attr.lua_module.html); [blink.cmp lib.rs](https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/rust/lib.rs)).

**File names and extensions trip up macOS users.** Cargo produces `libfoo.so` on Linux, `libfoo.dylib` on macOS and `foo.dll` on Windows MSVC (no `lib` prefix). Neovim's runtimepath loader searches for `lua/foo.<ext>`, taking suffixes from the initial `package.cpath`. `vim.loader` only considers `.dll` and `.so` ([lua.txt](https://github.com/neovim/neovim/blob/master/runtime/doc/lua.txt); [loader.lua](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/loader.lua)). That leaves two working conventions:

- Copy the library to `lua/foo.so`, **renaming the macOS `.dylib` to `.so`** as well. avante's Makefile does this, noting that "nvim will find .so automatically in rtp" ([avante Makefile](https://github.com/yetone/avante.nvim/blob/main/Makefile)).
- Leave the library in `target/release` and load it by explicit path.

**Each platform needs its own linker settings.** Linux builds need nothing special. On macOS the `lua_*` symbols must stay unresolved until load time, so you need `-undefined dynamic_lookup`. mlua's own test crate sets this from `build.rs` with `cargo:rustc-cdylib-link-arg`, and that setting travels with the crate where a `.cargo/config.toml` would not ([tests/module/build.rs](https://github.com/mlua-rs/mlua/blob/main/tests/module/build.rs)). It works because Neovim links `nvim` with `-Wl,-export_dynamic` ([src/nvim/CMakeLists.txt](https://github.com/neovim/neovim/blob/master/src/nvim/CMakeLists.txt)). On Windows, mlua emits `raw-dylib` imports against `lua51.dll`, which Neovim ships, so no import `.lib` is needed unless `LUA_LIB_NAME` overrides it ([mlua-sys lua51/lua.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/src/lua51/lua.rs)). blink.cmp builds its Windows DLLs with no extra settings. Its musl targets add `-C target-feature=-crt-static`, because a statically linked musl cdylib cannot be `dlopen`ed ([blink.cmp .cargo/config.toml](https://github.com/saghen/blink.cmp/blob/main/.cargo/config.toml)).

The minimal plugin below puts these pieces together. It is assembled from mlua's test crate and blink.cmp's patterns and was not compiled during this research, so run `cargo check` against 0.12.2, particularly for the userdata method bounds that 0.12 added with `MaybeSync`.

```toml
# Cargo.toml
[lib]
crate-type = ["cdylib"]
[dependencies]
mlua = { version = "0.12", features = ["luajit", "module", "serde"] }
serde = { version = "1", features = ["derive"] }
[profile.release]
lto = true
codegen-units = 1   # keep the default panic = "unwind"
```

```rust
// build.rs — check the *target* OS so cross-compiles work
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-cdylib-link-arg=-undefined");
        println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
    }
}

// src/lib.rs
use mlua::prelude::*;

fn word_count(_: &Lua, text: LuaString) -> LuaResult<usize> {
    Ok(text.to_str()?.split_whitespace().count())
}

#[mlua::lua_module(name = "novelist_native", skip_memory_check)]
fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let t = lua.create_table()?;
    t.set("word_count", lua.create_function(word_count)?)?;
    Ok(t)
}
```

Copy `libnovelist_native.so` (or the `.dylib`) to `lua/novelist_native.so`, or `novelist_native.dll` to `lua/novelist_native.dll` on Windows. On the Lua side, wrap the load in `pcall(require, "novelist_native")` and fall back or warn if it fails, as avante does ([avante tokenizers.lua](https://github.com/yetone/avante.nvim/blob/main/lua/avante/tokenizers.lua)).

## Rust sees Neovim only as Lua tables

mlua has no Neovim-specific API, by design. `Lua::entrypoint` wraps the host's `lua_State`, so the `&Lua` your module receives is Neovim's own interpreter, and `lua.globals()` contains `vim` ([src/state.rs](https://github.com/mlua-rs/mlua/blob/main/src/state.rs)). Calling the editor looks like this: `lua.globals().get::<LuaTable>("vim")?.get::<LuaTable>("api")?.get::<LuaFunction>("nvim_buf_get_lines")?.call::<Vec<String>>((0, 0, -1, false))?`. Autocmd, keymap and `vim.schedule` callbacks are `lua.create_function(...)` closures passed in as arguments. All of Neovim's normal rules still apply. In particular, `vim.api` calls from `vim.uv` callbacks are errors unless wrapped in `vim.schedule` ([Neovim :h lua](https://neovim.io/doc/user/lua/)). The only mlua-based `vim` wrapper crate, nvim-utils, was archived in 2023 ([nvim-utils](https://github.com/willothy/nvim-utils)). Neither the research notes nor the production plugins show any reason to drive the editor from Rust this way. A `vim.api` call routed through mlua is no faster than the same call in Lua, and it gives up readability. The native module earns its place with **pure computation over plain data**. Editor calls should stay in Lua.

Function signatures are typed in the way that matters for this kind of work. `lua.create_function(|lua, args: A| -> LuaResult<R>)` takes any `FromLuaMulti` tuple and returns any `IntoLuaMulti` tuple. blink.cmp accepts `(String, Vec<LspItem>)` and returns four parallel vectors as four Lua return values ([blink.cmp lib.rs](https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/rust/lib.rs)). With the `serde` feature, `lua.from_value::<Opts>(v)?` deserializes a `setup({...})` table straight into a `#[derive(Deserialize)]` struct, and `to_value` converts the other way ([serde/mod.rs](https://github.com/mlua-rs/mlua/blob/main/src/serde/mod.rs)). Stateful objects implement `UserData` with `add_methods` and `add_fields`, or, since 0.12, use `#[derive(UserData)]` with `#[mlua::userdata_impl]` ([src/userdata.rs](https://github.com/mlua-rs/mlua/blob/main/src/userdata.rs)). Errors follow ordinary Rust conventions. Returning `Err` raises a normal Lua error that `pcall` can catch, and mlua's error `__tostring` prints full stack traces, which the changelog says is "useful in a module mode". Panics inside callbacks are also caught by default (`catch_rust_panics = true`) and surfaced as Lua errors ([CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)). This is a real advantage over nvim-oxi, where returning `Err` from a callback has crashed Neovim ([nvim-oxi issue #231](https://github.com/noib3/nvim-oxi/issues/231)).

**Most tutorials online are out of date.** mlua's API changed substantially between 0.9 and 0.12 ([CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md); [v0.10 release notes](https://github.com/mlua-rs/mlua/blob/main/docs/release_notes/v0.10.md)):

| Version | API change |
|---|---|
| 0.9 | `ToLua` renamed to `IntoLua` |
| 0.10 | **The `'lua` lifetime was removed**: handles are `'static` and hold weak references to the state. `get::<_, T>` became `get::<T>`. The experimental `Owned*` types were removed. `TableExt` merged into `ObjectLike` |
| 0.11 | `serialize` renamed to `serde`. `set_metatable` became fallible |
| 0.12 | Root re-exports moved into submodules (the prelude still has them). Userdata types now need `MaybeSync`. Tables with the array metatable always serialize as arrays |

The lifetime removal is the change that matters most for plugins. You can now store a `LuaFunction` in a struct to call later. Clear stored handles explicitly, though: a `RegistryKey` is not freed on drop and needs `remove_registry_value` ([docs.rs RegistryKey](https://docs.rs/mlua/latest/mlua/struct.RegistryKey.html)).

## Only the main thread may touch Lua, and mlua's async does not change that

Neovim's `lua_State` is single-threaded, and with `send` disabled in module mode "since we don't have exclusive access to Lua" ([CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)), every `Lua`, `LuaTable` and `LuaFunction` is `!Send`. The compiler therefore stops you from touching Lua off the main thread, which is a useful safety property. The cost is that plain mlua has nothing like nvim-oxi's `libuv::AsyncHandle`, so a Rust thread has no supported way to wake Neovim's event loop. Production plugins follow the same pattern. Background work runs in `std::thread` (or a private runtime) on plain Rust data, results go into `static` `LazyLock<RwLock<…>>` state, and Lua *pulls* those results. fff spawns indexing threads and lets Lua ask `is_scanning()` or call `wait_for_initial_scan(timeout_ms)`, and it drives UI updates from `vim.uv` timers wrapped in `vim.schedule_wrap` ([fff.nvim](https://github.com/dmtrKovalenko/fff.nvim)). fff's source also records the main hazard of this design. A `FILE_PICKER.read()` on the UI thread blocked behind a long reindex writer "could freeze the nvim main loop for the entire duration of an in-progress scan". The fix moved the lock into the worker so that "the main thread always returns instantly". The general rule is to never take on the main thread a lock that a worker can hold for long. Use `try_read` or an `Arc` swap instead.

blink.cmp shows a second, less obvious technique. For roughly 10 ms frecency DB writes it calls `vim.uv.new_work`, and the worker thread `loadlib`s the same library into its own separate Lua state, receiving data serialized with `string.buffer` or `vim.mpack` ([blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)). This works because a library is mapped only once per process, so its Rust statics are shared across Lua states. The worker's Lua state has no access to editor state, so only pure-data functions belong there.

mlua's `async` feature is coroutine-based. An async Rust function becomes a Lua function that yields a "pending" marker until its future completes, and nothing in Neovim polls Rust futures. The mlua maintainer's advice in 2021 was to wrap the call in `coroutine.wrap` and have `vim.schedule` keep resuming it, because a blocking poll loop "would cause nearly 100% cpu usage" and tokio futures need a tokio runtime context anyway. A later user calling an async function directly from Neovim hit `attempt to yield across C-call boundary` ([mlua issue #76](https://github.com/mlua-rs/mlua/issues/76)). **None of blink.cmp, fff or avante enables `async`** ([fff](https://github.com/dmtrKovalenko/fff.nvim), [blink.cmp](https://github.com/Saghen/blink.cmp), [avante.nvim](https://github.com/yetone/avante.nvim)). The practical design is therefore threads plus channels plus a Lua-side timer poll, with every editor mutation inside `vim.schedule`. Bound that queue: lualine shipped a memory bug from an "unbounded vim.schedule() backlog when the main loop is blocked" ([lualine #1522](https://github.com/nvim-lualine/lualine.nvim/issues/1522)). Whether Neovim's proposed `vim.async` ([PR #34473](https://github.com/neovim/neovim/pull/34473)) changes this picture is not yet established.

## Rust pays off only when each call does real work

Every call from LuaJIT into an mlua function goes through the classic `lua_CFunction` API, which LuaJIT cannot compile into a trace. It can only "stitch" around the call, an approach the LuaJIT docs describe as "not particularly efficient" ([LuaJIT NYI list](https://github.com/tarantool/tarantool/wiki/LuaJIT-Not-Yet-Implemented)). mlua then adds `lua_pcall` protection around any C API operation that can raise an error, including each `lua_next` during table iteration. In one benchmark, summing a field across 10,000 tables from Rust ran **about 14.7x slower than pure Lua**. The maintainer's first recommendation was `skip_memory_check` ([mlua issue #318](https://github.com/mlua-rs/mlua/issues/318)). The rule that follows is to cross the boundary rarely and do a lot of work each time. blink.cmp shows how. It pushes each provider's completion items into a Rust `static` once, because "Lua <-> Rust takes the majority of the time". After that, each keystroke sends only the query and gets back compact arrays of indices and scores ([blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)). The good fits are SIMD fuzzy matching, file indexing, tokenizers, template engines, HTML-to-markdown conversion, and TOML editing that preserves formatting, which together cover nearly the whole list of production mlua modules. Small helpers that LuaJIT compiles well will usually run faster in Lua. No 2025–2026 benchmark of per-call overhead exists comparing mlua, nvim-oxi and raw LuaJIT FFI, so any claimed latency advantage among in-process approaches is unproven.

The way production plugins are structured follows from this rule. blink.cmp keeps the algorithm in the standalone `frizbee` crate (which also has C, Python and WASM bindings) and a thin mlua crate in `lua/blink/cmp/fuzzy/rust/` ([frizbee](https://github.com/saghen/frizbee/blob/main/Cargo.toml)). fff is a workspace whose `fff-core` also powers an MCP server, a C API and Python bindings, with only `fff-nvim` linking mlua. avante ships four separate cdylibs ([fff Cargo.toml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/Cargo.toml); [avante Cargo.toml](https://github.com/yetone/avante.nvim/blob/main/Cargo.toml)). The split also simplifies testing. A crate built with the `module` feature cannot easily run `cargo test`, because its Lua symbols are expected to come from a host process. fff's CI therefore runs `cargo test --workspace --exclude fff-nvim` and tests the glue separately with plenary under `nvim --headless` against a pinned Neovim ([fff workflows](https://github.com/dmtrKovalenko/fff.nvim)). avante runs busted under `nlua` with isolated XDG directories ([avante run-luatest.sh](https://github.com/yetone/avante.nvim)). Both plugins keep a pure-Lua option: blink.cmp ships a full Lua fuzzy matcher selectable with `implementation = 'lua'`, and avante simply disables the affected feature when the module is missing ([blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)).

## Distribution is the hard part: one binary per triple, never overwritten in place

The decisive advantage of mlua appears at release time. Because only the LuaJIT ABI is involved, **one artifact per target triple** serves every Neovim version. blink.cmp's tag-triggered release matrix builds 13 targets plus an OpenBSD VM job:

- glibc and musl Linux on x86_64, aarch64 and loongarch64;
- Android;
- FreeBSD;
- macOS x86_64 and arm64, built with `MACOSX_DEPLOYMENT_TARGET=13`;
- Windows x86_64 and aarch64 MSVC.

Linux targets are built with `cross`. Each artifact gets a `.sha256` file and is attached to the GitHub Release ([blink.cmp release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml)). fff uses `cargo zigbuild` with a glibc-pinned target such as `x86_64-unknown-linux-gnu.2.31`. avante uses a native ARM runner and a `manylinux2014` container ([fff release.yaml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/.github/workflows/release.yaml); [avante release.yaml](https://github.com/yetone/avante.nvim/blob/main/.github/workflows/release.yaml)). The glibc baselines conflict, and the conflict is unresolved. blink.cmp and avante target 2.17, while fff says "Rust 1.91+ requires glibc >= 2.31" and that 2.17 targets "no longer link". Neither claim was checked against Rust's platform-support docs, so test on an old distro before you choose.

On the client side, prebuilt binaries are fetched from a plugin-manager hook, with `cargo build --release` as the fallback. Release assets are named `<triple>.<ext>` ([fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)). blink.lib (the shared native-library helper behind blink.cmp v2 and blink.pairs) handles each step as follows ([blink.lib platform.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/platform.lua); [managed.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/managed.lua); [native/init.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/init.lua)):

- **Platform:** taken from `jit.os` and `jit.arch`.
- **musl vs glibc:** decided by reading the `PT_INTERP` string from `/proc/self/exe`.
- **Version guard:** the first 7 characters of the git commit go into the library's filename, so a stale binary is simply not found. This guard works only when users pin to a release tag.
- **Install hook:** a `build()` or `download()` task that the lazy.nvim or vim.pack hook waits on with `:pwait()`.

Versioning is a common source of user confusion. blink requires a pinned tag ("have you pinned the version?"), while avante tells users `version = false, -- Never set this value to "*"! Never!` and always fetches the latest tag ([avante README](https://github.com/yetone/avante.nvim/blob/main/README.md)). Checksums have regressed. blink's v1 client verified `.sha256` files with `sha256sum` or `certutil`, but the current blink.lib downloader only checks that the library loads. fff and avante do no checksum verification at all, even though blink's CI still publishes the hashes ([blink.cmp v1.6.0 files.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/files.lua)). For source installs, LuaRocks users get `luarocks-build-rust-mlua`, which maps the host Lua to the right mlua feature and runs cargo. It is how toml-edit.lua reaches rocks.nvim ([luarocks-build-rust-mlua](https://github.com/mlua-rs/luarocks-build-rust-mlua/blob/main/src/luarocks/build/rust-mlua.lua)). blink.cmp's `flake.nix` covers Nix users.

**A loaded library can never be replaced in a running Neovim**, and every serious plugin works around this. A second `package.loadlib` on the same path "returns the *cached* handle", so fff downloads to `<path>.tmp` and validates that copy with `loadlib` before renaming it into place. On Windows, renaming over a loaded DLL fails, so fff leaves the verified `.tmp` file and promotes it on the next start ([fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)). blink.lib renames the old file to `.old.<hash>` and unlinks it rather than writing into a mapped file. Both plugins load by absolute path through `package.loadlib` rather than `require`, because fff found that `require` "can find the wrong lib due to cpath pollution" ([fff rust/init.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/rust/init.lua)). The development loop is therefore: `cargo build`, restart Neovim, and have the loader also search `target/release` and `$CARGO_TARGET_DIR` so no copy step is needed.

The common failures and their fixes:

| Symptom | Cause | Fix |
|---|---|---|
| `compile_error!` on build | `vendored`, `send`, or two Lua features combined with `module` | `["luajit", "module"]` only |
| macOS link error for `_lua_*` | no `dynamic_lookup` | `build.rs` with `cargo:rustc-cdylib-link-arg` |
| `module not found` on macOS | `.dylib` not in Neovim's search suffixes | copy as `lua/name.so`, or `loadlib` by path |
| "symbol not found" / "procedure could not be found" | `luaopen_` name does not match module path; stale or wrong-arch binary | match `name =` to the dotted path; rebuild; check with `ldd` ([blink.cmp #2299](https://github.com/saghen/blink.cmp/discussions/2299)) |
| Silent Neovim death | panic in your own thread, `panic = "abort"`, or `unsafe` UB | keep unwinding; `catch_unwind` in workers; panic hook that logs to a file |
| Editor freezes | main thread blocked on a worker's lock, or sync call too heavy | `try_read`, snapshots, poll with timeouts |

mlua catches panics only in Lua-called callbacks. It states plainly that it "does not provide absolute safety even without `unsafe`", and its 0.12.2 release still fixed "panic and error handling in callbacks and userdata destructors to avoid corrupting Lua state" ([mlua README](https://github.com/mlua-rs/mlua); [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)). fff installs both a panic hook and a SIGSEGV handler because otherwise "a crash inside fff produces a silent nvim death — neovim's own handler does not log a Rust-side backtrace" ([fff.nvim](https://github.com/dmtrKovalenko/fff.nvim)).

## mlua is the default; nvim-oxi and RPC fit narrow cases

The three options differ mainly in what the binary depends on. **nvim-oxi** calls Neovim's exported `nvim_*` C functions directly through typed builders. Its option structs mirror Neovim's internal `#[repr(C)]` keysets, so each binary works with one Neovim minor version. The crates.io release (0.6.0, May 2025) supports only Neovim 0.10 and 0.11. Support for 0.12 exists only on git `main`, which has had no commits since May 2026, and `set_hl` aborts on Neovim 0.12.2 ([nvim-oxi issue #311](https://github.com/noib3/nvim-oxi/issues/311); [nvim-oxi](https://github.com/noib3/nvim-oxi)). Its flagship plugin, nomad, ships separate assets for each Neovim version and each platform, with no Windows builds ([nomad installation](https://raw.githubusercontent.com/nomad/nomad/main/docs/installation.md)). **RPC** through nvim-rs runs as a separate process. It provides process isolation, native tokio, and an API generated from Neovim's API metadata. The costs are an IPC round trip on every call, the need for a Lua shim to forward keymap and autocmd events, and an API its own README calls "unstable" ([nvim-rs](https://github.com/KillTheMule/nvim-rs)). Neovim's legacy remote-plugin route also needs `:UpdateRemotePlugins` after every install or update ([:h remote-plugin](https://neovim.io/doc/user/remote_plugin/)).

| | mlua module | nvim-oxi | RPC (nvim-rs) |
|---|---|---|---|
| Binary coupled to | LuaJIT 5.1 C API (frozen) | Neovim minor version | msgpack API levels (versioned) |
| Editor API from Rust | dynamic via `vim.*`, untyped | typed `nvim_*` wrappers, gaps in lsp/ui/treesitter/`vim.fn` | full generated API, `rmpv::Value` |
| In-process callbacks | yes | yes | no (Lua shim + `rpcnotify`) |
| Background work | threads + Lua polling; no loop wake-up | `libuv::AsyncHandle` (shaky on Windows/Termux) | native async |
| Errors | `Err` and panics become Lua errors | `Err` across the boundary has crashed Neovim | process isolated |
| Release cadence (Oct 2026) | 0.12.2, 3 Oct 2026 | 0.6.0, May 2025 | 0.9.2, 2025 |
| Major users | blink.cmp, fff, avante, rocks.nvim (via toml-edit.lua) | nomad | few |

Choose mlua when Rust is a compute or data backend behind a Lua UI, and when you want one binary per platform that keeps working across Neovim upgrades. That describes most Rust-in-Neovim projects. Choose nvim-oxi only when most of the logic must drive the editor API from Rust with compile-time types, and you can pin a git revision and build once per Neovim minor version. Even nvim-oxi contributors are moving toward mlua: the nvimo fork replaces nvim-oxi's Lua layer with mlua for its "robust error and panic propagation" ([nvimo](https://github.com/c-c-k/nvimo)). Choose RPC when a crash must not take down the editor, when the backend is a long-running network service, or when the same binary must also serve other hosts. Keep it off per-keystroke paths.

## Conclusion

A Rust Neovim plugin built on mlua mostly lives in its Lua code. Because Rust sees Neovim only through Lua, plugins hand all editor interaction to Lua and keep Rust as a stateless or `static`-backed engine over plain data. That one choice decouples the binary from Neovim releases, makes the compiler enforce main-thread discipline, keeps tests in plain `cargo test`, and lets a plugin degrade to pure Lua when the binary is missing. The decisions that take engineering effort are about releasing, not about the language: which glibc baseline to target, how to tie binary versions to git tags, whether to verify checksums, and how to swap a library that cannot be unloaded. The ecosystem has not settled any of these, and each production plugin has made different choices.

For a new plugin, the practical recommendation is: start on mlua 0.12 with `["luajit", "module", "serde"]` and `skip_memory_check`; split the code into a core crate and a glue crate from day one; load by absolute path with `package.loadlib`; and copy blink.lib's commit-hashed filenames and stage-then-rename updates, adding back the checksum verification that current clients dropped. The open gaps sit around concurrency. Plain mlua has no supported way to wake Neovim's event loop from a Rust thread, its `async` feature has no production user in Neovim, and nobody has published latency numbers comparing timer polling with an async-handle wake-up. Until one of those changes, poll from Lua and keep each Rust call short.
