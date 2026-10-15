# Rust Neovim Plugins via mlua Module Mode: Build Setup and Core Mechanics

(Researched 2026-10-11. Primary sources: mlua repo at `main` and crates.io, Neovim repo at `master`, and the blink.cmp plugin as a real-world reference.)

## 1. Current mlua version and Cargo features for Neovim

### Takeaway
As of October 2026 the current mlua release is **0.12.2** (released 2026-10-03). For Neovim, use `features = ["luajit", "module"]`, adding `serde`, `async` or `macros` if you need them. Do **not** enable `vendored` or `send`; with `module` they are compile errors. Use `luajit`, not `luajit52`, because Neovim's bundled LuaJIT is built without Lua 5.2 compatibility.

### Cited Findings
- crates.io reports `max_stable_version` = 0.12.2, updated 2026-10-03. mlua's `Cargo.toml` shows `version = "0.12.2"`, `rust-version = "1.88"`, `edition = "2024"`, and depends on `mlua-sys` 0.13.0. — [crates.io API](https://crates.io/api/v1/crates/mlua); [mlua Cargo.toml](https://github.com/mlua-rs/mlua/blob/main/Cargo.toml)
- Release timeline: v0.12.2 (Oct 03 2026), v0.12.1 (Aug 29 2026), v0.12.0 (Jul 05 2026), v0.11.0 (Jul 14 2025), v0.10.0 (Oct 25 2024). — [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- The README install snippet uses `mlua = { version = "0.12", ... }`. No feature is enabled by default. — [mlua README](https://github.com/mlua-rs/mlua)
- Feature flags in the 0.12.2 `Cargo.toml`:
  - Lua versions: `lua55`, `lua54`, `lua53`, `lua52`, `lua51`, `luajit`, `luajit52` (= `luajit` + `ffi/luajit52`), plus `luau`, `luau-jit` and `luau-vector4`.
  - Other: `vendored`, `module` (= `mlua_derive` + `ffi/module`), `async`, `send` (implies `error-send`), `error-send`, `serde`, `macros`, `anyhow`, `userdata-wrappers`.
  - Deprecated: `serialize = ["serde"]`.
  - [mlua Cargo.toml](https://github.com/mlua-rs/mlua/blob/main/Cargo.toml)
- **`serialize` → `serde` rename:** "New `serde` feature flag to replace `serialize` (the old one is still available)" (v0.11.0-beta.2). Older tutorials that use `features = ["serialize"]` still compile but are outdated. — [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- You must pick exactly one Lua version feature. The `mlua-sys` build script fails otherwise: `compile_error!("You can enable only one of the features: lua55, lua54, ... luajit, luajit52, luau")`. — [mlua-sys build/main.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main.rs)
- **`vendored` and `module` are mutually exclusive, enforced at compile time.** The build script contains `compile_error!("`vendored`, `external` and `module` features are mutually exclusive")`. This has applied since v0.9.0-rc.2, which also switched to the `C-unwind` ABI. — [mlua-sys build/main_inner.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main_inner.rs); [CHANGELOG v0.9.0-rc.2](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- In module mode the build script does not probe for or link a Lua library (`#[cfg(not(feature = "module"))] find::probe_lua();`). The README says: "Module builds don't require Lua binaries or headers to be installed on the system." — [main_inner.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main_inner.rs); [README](https://github.com/mlua-rs/mlua)
- **`send` is forbidden in module mode.** The source has `compile_error!("`send` feature is not supported in module mode")`, and the changelog says "Disabled `send` feature in module mode (since we don't have exclusive access to Lua)" (v0.10.0-beta.2). The v0.10 release notes put the cost of `send` at about 10–20% when it is used. — [src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/src/lib.rs); [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md); [v0.10 release notes](https://github.com/mlua-rs/mlua/blob/main/docs/release_notes/v0.10.md)
- `luajit52` only switches LuaJIT's `lua52compat` build option (`.lua52compat(cfg!(feature = "luajit52"))` in the vendored builder). — [find_vendored.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/find_vendored.rs)
- Neovim's bundled LuaJIT build flags (`BuildLuajit.cmake`) are `CFLAGS=-fPIC -DLUA_USE_APICHECK -funwind-tables` and contain no `LUAJIT_ENABLE_LUA52COMPAT`. — [neovim BuildLuajit.cmake](https://github.com/neovim/neovim/blob/master/cmake.deps/cmake/BuildLuajit.cmake)
- Neovim documents that it "officially only requires Lua 5.1 support" but "should be built with LuaJIT", and that plugins should check the `jit` global before relying on LuaJIT extensions. — [neovim runtime/doc/lua.txt `lua-luajit`](https://github.com/neovim/neovim/blob/master/runtime/doc/lua.txt)
- Real-world reference: blink.cmp's fuzzy matcher uses `mlua = { version = "0.11.3", features = ["module", "luajit"] }`, `crate-type = ["cdylib"]`, and release `lto = true, codegen-units = 1`. — [blink.cmp Cargo.toml](https://github.com/saghen/blink.cmp/blob/main/Cargo.toml)
- `async` is available, and `LuaOptions::thread_pool_size` is gated on it. — [src/state.rs](https://github.com/mlua-rs/mlua/blob/main/src/state.rs)
- `macros` is required for `chunk!`, `#[derive(FromLua)]`, `#[derive(UserData)]` and `#[mlua::userdata_impl]`. `lua_module` only needs `module`. — [src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/src/lib.rs)

### Inferences
- **Why `vendored` must not be used in module mode:** a module has to call the *host's* Lua C API, meaning the LuaJIT already running inside `nvim`. Vendoring would statically link a second LuaJIT runtime into the `.so`. Its `lua_*` functions would then operate on a `lua_State` created by a different copy of the VM, with separate globals and allocator assumptions. The likely result is crashes or memory corruption. mlua turns this mistake into a compile error. This rationale is inferred from the build logic; the changelog only states that the features are mutually exclusive.
- **Recommended dependency line for Neovim:** `mlua = { version = "0.12", features = ["luajit", "module", "serde"] }`. Add `macros` for the derive macros and `async` only if you really drive Lua coroutines from Rust futures.
- Neovim enables `LUA_USE_APICHECK` in its LuaJIT build, so C API misuse may trigger assertions instead of silent corruption. That helps when debugging unsafe `ffi` code.

### Gaps
- `async` in module mode has no Neovim-specific guidance. Neovim does not poll Rust futures, so it is unclear how a Rust `async fn` exposed to Lua would be driven inside Neovim's event loop. I found no source covering this.
- Some distros build Neovim against PUC Lua 5.1 instead of LuaJIT. I could not confirm whether a module built with the `luajit` feature loads in such a build; it may reference LuaJIT-only symbols.

---

## 2. `#[mlua::lua_module]`: entry point naming, `name =`, `skip_memory_check`, return value

### Takeaway
The macro wraps `fn foo(lua: &Lua) -> LuaResult<T>` in an exported `extern "C-unwind" fn luaopen_foo(state)`. `name = "x"` changes the symbol to `luaopen_x`, and `skip_memory_check` turns off protected-mode allocation checks for speed. You usually return a `LuaTable` of functions, but any `IntoLua` value is accepted. You can define several entry points in one cdylib.

### Cited Findings
- Expansion, quoted from `mlua_derive/src/module.rs`:
  ```rust
  let module_name = args.name.unwrap_or_else(|| func_name.clone());
  let ext_entrypoint_name = format_ident!("luaopen_{}", module_name);
  ...
  #[unsafe(no_mangle)]
  unsafe extern "C-unwind" fn #ext_entrypoint_name(state: *mut mlua::lua_State) -> c_int {
      mlua::Lua::entrypoint1(state, move |lua| { #skip_memory_check #func_name(lua) })
  }
  ```
  [mlua_derive module.rs](https://github.com/mlua-rs/mlua/blob/main/mlua_derive/src/module.rs)
- `name` is parsed as a string literal and then as a Rust **identifier** (`value.parse::<LitStr>()?.parse()?` into `Ident`), so it cannot contain `.` or `-`. `skip_memory_check` takes no value. Any other attribute fails with "unsupported module attribute". — [module.rs](https://github.com/mlua-rs/mlua/blob/main/mlua_derive/src/module.rs)
- `entrypoint1` requires `F: FnOnce(&Lua) -> Result<R>, R: IntoLua`, so the return type is any `IntoLua` value, not only a table. — [src/state.rs](https://github.com/mlua-rs/mlua/blob/main/src/state.rs)
- docs.rs (0.12.2) describes the macro as follows:
  - It is available only with `module`.
  - "Registers Lua module entrypoint."
  - "You can register multiple entrypoints as required."
  - The `name` option defaults to the function name.
  - "skip_memory_check - skip memory allocation checks for some operations." mlua cannot know whether the host Lua environment has memory limits, so some allocation-heavy operations run in protected mode by default. Skipping those checks improves performance but risks uncaught exceptions and memory leaks.

  [docs.rs lua_module](https://docs.rs/mlua/latest/mlua/attr.lua_module.html)
- mlua's own module test shows plain, renamed and failing entry points:
  - `#[mlua::lua_module] fn r#test_module(lua: &Lua) -> LuaResult<LuaTable>`
  - `#[mlua::lua_module(name = "test_module_second", skip_memory_check)] fn test_module2(...)`
  - Returning `Err("custom module error".into_lua_err())` makes `require` raise an error.

  [tests/module/src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/tests/module/src/lib.rs)
- History:
  - `skip_memory_check` was added in v0.9.0-rc.1.
  - "Support setting module name in `#[lua_module(name = "...")]` macro" was added in v0.9.0-beta.1.

  [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- blink.cmp uses `#[mlua::lua_module(skip_memory_check)] fn blink_cmp_fuzzy(lua: &Lua) -> LuaResult<LuaTable>` and sets each export with `exports.set("name", lua.create_function(f)?)?`. — [blink.cmp lib.rs](https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/rust/lib.rs)
- Neovim derives the symbol it looks for from the module name, following Lua 5.1 rules:
  - (a) strip the prefix up to and including the first `-`;
  - (b) replace dots with underscores;
  - (c) prepend `luaopen_`.

  So `"foo-bar.baz"` → `luaopen_bar_baz`. The code is `package.loadlib(ret.modpath, 'luaopen_' .. funcname:gsub('%.', '_'))`. — [neovim runtime/lua/vim/loader.lua](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/loader.lua)

### Inferences
- For a namespaced plugin such as `require("novelist.native")`, either:
  - name the Rust function `novelist_native`, or
  - use `#[mlua::lua_module(name = "novelist_native")]`,

  and place the library at `lua/novelist/native.so`. Neovim will then look up `luaopen_novelist_native`.
- Neovim's LuaJIT runs without a memory limit, and blink.cmp uses `skip_memory_check` in production. That makes it a reasonable choice for Neovim plugins that are sensitive to performance, accepting that an out-of-memory error inside an allocation could leak instead of being caught.

### Gaps
- None significant.

---

## 3. cdylib output naming, runtimepath placement and `package.cpath`

### Takeaway
Cargo builds `lib<crate>.so` on Linux, `lib<crate>.dylib` on macOS and `<crate>.dll` on Windows (MSVC, no `lib` prefix). Neovim's runtimepath loader looks for `lua/<mod path>.<suffix>`, with suffixes taken from the initial `package.cpath` (`.so` on Unix, `.dll` on Windows). **On macOS you must copy or rename the `.dylib` to `.so`**, or else add the path to `package.cpath` yourself.

### Cited Findings
- Neovim's `lua-module-load` rules:
  - "For a module `foo.bar`, each directory is searched for `lua/foo/bar.lua`, then `lua/foo/bar/init.lua`."
  - "If no files are found, the directories are searched again for a shared library with a name matching `lua/foo/bar.?`, where `?` is a list of suffixes (such as `so` or `dll`) derived from the initial value of package.cpath."
  - "If still no files are found, Nvim falls back to Lua's default search mechanism."
  - "Nvim does not track current values of package.path or package.cpath."
  - Runtimepath entries that contain semicolons are skipped.

  [neovim lua.txt](https://github.com/neovim/neovim/blob/master/runtime/doc/lua.txt)
- `vim.loader` (the byte-compiling cache loader) searches libraries with `patterns = { is_win and '.dll' or '.so' }`, so it only considers `.so` on macOS and Linux. — [neovim loader.lua](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/loader.lua)
- blink.cmp, in its v1.x loader, picks the extension from `jit.os`:
  - `.dylib` on mac/osx, `.dll` on Windows, `.so` otherwise.
  - It then **appends to `package.cpath`** both `target/release/lib?<ext>` and `target/release/?<ext>`, "since MSVC doesn't include the prefix".
  - Finally it calls `require('blink_cmp_fuzzy')`.

  [blink.cmp v1.6.0 fuzzy/rust/init.lua](https://github.com/saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/rust/init.lua)
- blink.cmp CI artifacts:
  - `target/<triple>/release/libblink_cmp_fuzzy.so` on Linux,
  - `.../libblink_cmp_fuzzy.dylib` on macOS, built with `MACOSX_DEPLOYMENT_TARGET="13"`,
  - `.../blink_cmp_fuzzy.dll` on Windows MSVC (x86_64 and aarch64).

  Its build command checks `CARGO_TARGET_DIR` and both prefixed and unprefixed names. — [blink.cmp release.yaml](https://github.com/saghen/blink.cmp/blob/main/.github/workflows/release.yaml); [blink.cmp init.lua](https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/init.lua)

### Inferences
- **Option A (Neovim-native discovery):** copy the build output into the plugin as `lua/<name>.so` on Linux and macOS (renaming macOS `lib<name>.dylib` to `<name>.so`) or `lua/<name>.dll` on Windows. A plain `require("<name>")` then works with no cpath changes, including under `vim.loader.enable()`. Keep the `lib` prefix out of the installed filename, because the filename is the module name.
- **Option B (the blink.cmp approach):** leave the library in `target/release` and prepend or append both `lib?` and `?` patterns to `package.cpath` before calling `require`. This works with the stock `.dylib` name because the extension is spelled out explicitly.
- On Linux you can replace a loaded `.so` in place, but Neovim will not reload it. `dlopen` caches the handle and `require` caches the module, so restart Neovim after rebuilding. On Windows the loaded DLL is locked, so build to a temporary path and swap it in on next start.

### Gaps
- I found no official Neovim statement on whether `.dylib` is ever in the default macOS `package.cpath` of Neovim's LuaJIT. The `.so`-only pattern in `vim.loader` strongly suggests it is not.

---

## 4. Platform linker specifics (macOS, Windows, Linux)

### Takeaway
On Linux no special flags are needed. On macOS, symbols must stay unresolved until load time, so pass `-undefined dynamic_lookup`, either in `.cargo/config.toml` or via `build.rs`. On Windows, mlua emits `raw-dylib` imports against `lua51.dll` (for both `lua51` and `luajit`) unless `LUA_LIB_NAME` is set.

### Cited Findings
- README:
  - "On macOS, you need to set additional linker arguments": `cargo rustc -- -C link-arg=-undefined -C link-arg=dynamic_lookup`, or put `rustflags = ["-C","link-arg=-undefined","-C","link-arg=dynamic_lookup"]` in `.cargo/config.toml` for `x86_64-apple-darwin` and `aarch64-apple-darwin`.
  - "On Linux you can build modules normally with `cargo build --release`."
  - "On Windows the target module will be linked with the `lua5x.dll` library (depending on your feature flags)."

  [mlua README](https://github.com/mlua-rs/mlua)
- mlua's own module test uses a `build.rs` instead of `config.toml`, which also works when the crate is a dependency built by someone else:
  ```rust
  #[cfg(target_os = "macos")] {
      println!("cargo:rustc-cdylib-link-arg=-undefined");
      println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
  }
  ```
  [tests/module/build.rs](https://github.com/mlua-rs/mlua/blob/main/tests/module/build.rs)
- In `mlua-sys`, a Windows + `module` build emits `cargo:rustc-cfg=raw_dylib` unless the env var `LUA_LIB_NAME` is non-empty, in which case it falls back to normal library probing. — [main_inner.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main_inner.rs)
- The LuaJIT/5.1 FFI declarations carry `#[cfg_attr(all(windows, raw_dylib), link(name = "lua51", kind = "raw-dylib"))]`, so no import `.lib` is needed at build time. The changelog notes "Support vendored module mode for windows (raw-dylib linking, Rust 1.71+)" (v0.9.0-rc.2). — [mlua-sys src/lua51/lua.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/src/lua51/lua.rs); [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- Luau + `module` on Windows is a compile error ("Luau does not support `module` mode on Windows"). This does not affect Neovim. — [main_inner.rs](https://github.com/mlua-rs/mlua/blob/main/mlua-sys/build/main_inner.rs)
- Neovim's own build:
  - On Windows (MSVC) it builds LuaJIT both static and as `lua51.dll`, copying `lua51.dll` to the deps bin dir ("Luarocks searches for lua51.dll").
  - On macOS `nvim` is linked with `-Wl,-export_dynamic` "to actually export symbols" (neovim issue #25295), which is what makes `dynamic_lookup` modules resolve `lua_*` at load time.

  [BuildLuajit.cmake](https://github.com/neovim/neovim/blob/master/cmake.deps/cmake/BuildLuajit.cmake); [src/nvim/CMakeLists.txt](https://github.com/neovim/neovim/blob/master/src/nvim/CMakeLists.txt)
- blink.cmp's `.cargo/config.toml` carries the macOS flags. It also adds:
  - `-C target-feature=-crt-static` for musl targets, needed because a statically linked musl cdylib cannot be dlopened;
  - Android-specific `-rdynamic` flags.

  Its Windows CI uses a plain `cargo build --release --target x86_64-pc-windows-msvc` with no extra settings. — [blink.cmp .cargo/config.toml](https://github.com/saghen/blink.cmp/blob/main/.cargo/config.toml); [release.yaml](https://github.com/saghen/blink.cmp/blob/main/.github/workflows/release.yaml)
- A Neovim Discourse thread reports a Windows mlua module failing to load in Neovim with "procedure could not be found". The thread is titled "How to make mlua crate work with neovim in windows?", but I could not retrieve its resolution because the site was unreachable. — [neovim.discourse.group thread 4526](https://neovim.discourse.group/t/how-to-make-mlua-crate-work-with-neovim-in-windows/4526)

### Inferences
- blink.cmp ships prebuilt Windows DLLs built with default mlua settings to a large user base. That suggests a default raw-dylib `lua51.dll` import resolves correctly against official Neovim Windows builds. If a custom or other-distribution Neovim reports "procedure could not be found", check that `lua51.dll` is present next to `nvim.exe`, or experiment with `LUA_LIB_NAME`.
- Prefer the `build.rs` approach for macOS. It applies only to the cdylib (`rustc-cdylib-link-arg`) and travels with the crate, whereas `.cargo/config.toml` is ignored when the build runs from a different working directory or workspace root.

### Gaps
- I could not verify from primary sources whether the official `nvim-win64.zip` ships `lua51.dll` or whether `nvim.exe` itself exports the `lua_*` symbols. The Neovim CMake code shows `lua51.dll` copied to the deps bin dir, but I did not confirm its install rule for MSVC.

---

## 5. Exposing functions, userdata, conversions, serde and error handling

### Takeaway
Since mlua 0.10, Lua handle types (`Table`, `Function`, `AnyUserData`, ...) have **no `'lua` lifetime** and are `'static`. Functions are `lua.create_function(|lua, args: A| -> LuaResult<R>)`, where `A: FromLuaMulti` and `R: IntoLuaMulti`. Userdata implement `UserData::add_methods`/`add_fields`, or in 0.12 use `#[derive(UserData)]` with `#[mlua::userdata_impl]` (needs `macros`). Serde conversions go through `LuaSerdeExt::{to_value, from_value}`. Errors are `mlua::Error`; return `Err` to raise a Lua error.

### Cited Findings
- **Outdated-API flags, chronological:**
  - v0.9.0-beta.1: "`ToLua`/`ToLuaMulti` renamed to `IntoLua`/`IntoLuaMulti`".
  - v0.10.0-beta.1: "Dropped `'lua` lifetime (subtypes now store a weak reference to Lua)".
  - v0.10.0-beta.1: "Removed (experimental) owned types (they no longer needed)". `OwnedTable`/`OwnedFunction` from 0.9 are gone.
  - v0.10.0-beta.1: "Removed `UserData` impl for Rc/Arc types". In 0.11+ the `userdata-wrappers` feature covers these.
  - v0.10.0-beta.2: "Dropped lifetime from `UserDataMethods` and `UserDataFields` traits".
  - v0.10.0-beta.2: "`IntoLua`/`IntoLuaMulti` now uses `impl trait` syntax for args (shorten from `a.get::<_, T>` to `a.get::<T>`)".
  - v0.10.0-beta.2: "`TableExt` and `AnyUserDataExt` traits were combined into `ObjectLike` trait".
  - v0.11.0: "`Table::set_metatable` now returns `Result<()>`".
  - v0.11.0-beta.1: "`Lua::scope` pass `&Scope` instead of `&mut Scope`".
  - v0.12.0-rc.1: Rust 2024 edition.
  - v0.12.0-rc.1: "New `MaybeSync` trait that is required for userdata types".
  - v0.12.0-rc.1: "Changed interface of `Function::wrap/wrap_mut/wrap_async` to support any Error type".
  - v0.12.0-rc.1: "Changed `AnyUserData::type_name` to return `LuaString`".
  - v0.12.0-rc.1: "Removed `Error::ToLuaConversionError`".
  - v0.12.0-rc.1: "Added `UserDataOwned<T>`".
  - v0.12.0: "root re-exports are refactored (only essentials are re-exported, the rest is in the new submodules)". Some `mlua::X` paths moved to `mlua::chunk::`, `mlua::table::`, `mlua::function::` and similar; the prelude still re-exports them.

  [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- v0.10 release notes:
  - "all Lua types are `'static` and hold only weak references to the Lua instance".
  - `String::to_str` now returns `BorrowedStr`.
  - `Scope::create_nonstatic_userdata` was renamed to `Scope::create_userdata`.

  [v0.10 release notes](https://github.com/mlua-rs/mlua/blob/main/docs/release_notes/v0.10.md)
- 0.12 prelude names: `LuaTable`, `LuaFunction`, `LuaValue`, `LuaResult`, `LuaError`, `LuaUserData`, `LuaUserDataMethods`, `LuaUserDataFields`, `LuaAnyUserData`, `LuaUserDataRef`/`RefMut`, `LuaUserDataOwned`, `LuaMultiValue`, `LuaVariadic`, `LuaExternalError`/`LuaExternalResult`, `LuaErrorContext`, `LuaRegistryKey`, `LuaEither`, `WeakLua`, `IntoLua`, `FromLua`, `IntoLuaMulti`, `FromLuaMulti`. With `serde` it adds `LuaSerdeExt`, `LuaSerializeOptions`, `LuaDeserializeOptions` and `LuaSerializableValue`. — [src/prelude.rs](https://github.com/mlua-rs/mlua/blob/main/src/prelude.rs)
- The `UserData` trait in 0.12:
  - `fn add_fields<F: UserDataFields<Self>>(fields: &mut F)`
  - `fn add_methods<M: UserDataMethods<Self>>(methods: &mut M)`
  - `fn register(registry: &mut UserDataRegistry<Self>)`
  - Methods include `add_method(name: impl Into<String>, ...)`, `add_meta_method` and `add_field_method_get`.

  [src/userdata.rs](https://github.com/mlua-rs/mlua/blob/main/src/userdata.rs)
- `#[derive(UserData)]` and `#[mlua::userdata_impl]` were added in v0.12.0-rc.2 and are gated on the `macros` feature. v0.12.1 allows `userdata_impl` in a different module from the derive. — [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md); [src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/src/lib.rs)
- `LuaSerdeExt` provides:
  - `to_value<T: Serialize>(&self, &T) -> Result<Value>`
  - `to_value_with(.., SerializeOptions)`
  - `from_value<T: DeserializeOwned>(&self, Value) -> Result<T>`
  - `from_value_with(.., DeserializeOptions)`
  - `null()`
  - `array_metatable()`

  [src/serde/mod.rs](https://github.com/mlua-rs/mlua/blob/main/src/serde/mod.rs)
- Serde behaviour changes:
  - v0.12.0: "tables with the array metatable are always encoded as arrays". This matters because `vim.empty_dict()` and the `vim.json` conventions rely on metatables.
  - v0.12.2: `recursion_limit` (default 128) added to Serialize/DeserializeOptions.
  - v0.12.2: "Reject fractional numbers when converting to Rust integers on Lua 5.3+". This only applies to Lua 5.3+, so not to LuaJIT.
  - v0.10.4: `encode_empty_tables_as_array` option.

  [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- blink.cmp takes typed arguments directly. For example `(provider_id, items): (String, Vec<LspItem>)`, where `LspItem` implements `FromLua`, and it returns `LuaResult<(Vec<u16>, Vec<u32>, Vec<i32>, Vec<bool>)>`, which becomes multiple Lua returns of array tables. It converts custom error types with `map_err` and `?` into `LuaError`. — [blink.cmp lib.rs](https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/rust/lib.rs)
- **Panics:**
  - `LuaOptions::catch_rust_panics` defaults to **true**. Panics inside callbacks are caught at the FFI boundary and surfaced as Lua errors, catchable by `pcall`. "Panics are still automatically resumed if returned to the Rust side."
  - All FFI declarations and the generated entry point use `extern "C-unwind"`.
  - v0.12.2 says it fixed "panic and error handling in callbacks and userdata destructors to avoid corrupting Lua state".

  [src/state.rs](https://github.com/mlua-rs/mlua/blob/main/src/state.rs); [module.rs](https://github.com/mlua-rs/mlua/blob/main/mlua_derive/src/module.rs); [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- Errors render well in module mode: "Improved errors reporting (`Error`'s `__tostring` method formats full stacktraces). This is useful in a module mode." (v0.6.0). — [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- The `anyhow` feature implements `IntoLua` for `anyhow::Error`, added in v0.10.0-rc.1. — [CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)

### Inferences
- In Neovim, an `Err` returned from a Rust callback appears as a normal Lua error, for example in `:messages` or via `pcall`. Prefer returning errors, using `LuaError::external(e)` or `"msg".into_lua_err()`, over panicking. Panics are caught by default but leave Rust state such as a `Mutex` possibly poisoned.
- Since there is no `'lua` lifetime, you can store `LuaFunction` or `LuaTable` in Rust structs or statics-with-interior-mutability for later callbacks. They hold weak references and fail gracefully if the state is gone. Note that `send` is unavailable, so these handles are not `Send` and cannot cross into background threads. Send plain Rust data instead, and marshal back on the main thread.
- With `serde`, deserialize option tables such as `setup({...})` straight into `#[derive(Deserialize)]` structs via `lua.from_value::<Opts>(value)?`.

### Gaps
- I did not verify the exact attribute syntax of `#[derive(UserData)]`/`#[userdata_impl]` (for example `#[lua(...)]` field attributes); see `docs/UserData.md` in the mlua repo.

---

## 6. Calling the Neovim API from Rust inside mlua

### Takeaway
mlua has no Neovim-specific API. You reach Neovim through ordinary Lua values: `lua.globals().get::<LuaTable>("vim")?`, then `.get::<LuaTable>("api")?` and `.get::<LuaFunction>("nvim_buf_get_lines")?.call::<T>(args)?`. Callbacks for `vim.schedule`, autocmds and keymaps are `lua.create_function(...)` values passed as arguments. The usual Neovim rules apply: no `vim.api` calls from `vim.uv` callbacks without `vim.schedule` (E5560).

### Cited Findings
- `Lua::entrypoint` obtains the host state via `Self::get_or_init_from_ptr(state)`. The `&Lua` passed to your module function therefore wraps Neovim's own `lua_State`, and `lua.globals()` is Neovim's global table, including `vim`. — [src/state.rs](https://github.com/mlua-rs/mlua/blob/main/src/state.rs)
- mlua 0.10 changed `get` syntax to `get::<T>` (single type parameter); old code uses `get::<_, T>` and `call::<_, R>`. — [CHANGELOG v0.10.0-beta.2](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- Neovim: "It is an error to directly invoke `vim.api` functions (except api-fast) in `vim.uv` callbacks"; the fix is to wrap them with `vim.schedule_wrap`. `vim.schedule(fn)` "Schedules {fn} to be invoked soon by the main event-loop. Useful to avoid textlock or other temporary restrictions." — [neovim lua.txt](https://github.com/neovim/neovim/blob/master/runtime/doc/lua.txt)
- Alternatives:
  - **nvim-oxi** provides direct FFI bindings to the Neovim C API and documents an mlua integration with a `#[nvim_oxi::plugin]` cdylib entry point.
  - **nvim-utils**, an mlua-based `vim` wrapper, is archived: "This library is no longer maintained" (archived Jul 13 2023).

  [docs.rs nvim-oxi](https://docs.rs/nvim-oxi); [willothy/nvim-utils](https://github.com/willothy/nvim-utils)
- A Discourse user reported that nvim-oxi "doesn't work in windows, can't even compile" and fell back to plain mlua. I could not verify this against the current nvim-oxi state. — [neovim.discourse.group 4526](https://neovim.discourse.group/t/how-to-make-mlua-crate-work-with-neovim-in-windows/4526) (search snippet only)

### Inferences
- Pattern, written to mlua 0.12 API names; not compiled during this research:
  ```rust
  fn api(lua: &Lua) -> LuaResult<LuaTable> {
      lua.globals().get::<LuaTable>("vim")?.get::<LuaTable>("api")
  }
  // vim.api.nvim_buf_get_lines(0, 0, -1, false)
  let lines: Vec<String> = api(lua)?
      .get::<LuaFunction>("nvim_buf_get_lines")?
      .call((0, 0, -1, false))?;
  // vim.schedule(function() ... end)
  let vim: LuaTable = lua.globals().get("vim")?;
  let cb = lua.create_function(|lua, ()| { /* safe to call vim.api here */ Ok(()) })?;
  vim.get::<LuaFunction>("schedule")?.call::<()>(cb)?;
  // autocmd with a Rust callback
  let opts = lua.create_table()?;
  opts.set("pattern", "*.md")?;
  opts.set("callback", lua.create_function(|_, ev: LuaTable| {
      let buf: i64 = ev.get("buf")?; Ok(false) // returning true deletes the autocmd
  })?)?;
  api(lua)?.get::<LuaFunction>("nvim_create_autocmd")?.call::<i64>(("BufWritePost", opts))?;
  ```
- **Threading:** `Lua` is not `Send` in module mode, so background Rust threads cannot call into Lua. A common design keeps Lua as the orchestrator:
  - Rust exposes pure functions, such as parsing or text analysis, that take and return plain data.
  - The Lua side calls them synchronously, or polls a Rust-side result queue from a `vim.uv` timer wrapped in `vim.schedule_wrap`.
- Fetching `vim.api` on every call costs a few table lookups. For hot paths, cache the `LuaFunction` in a struct or a registry value (`lua.create_registry_value`). Handles are `'static` since 0.10, so this is easy.
- Keep the Rust side thin over the Neovim API. Calling `vim.api` from Rust through mlua offers no performance gain over Lua. The value of the native module is CPU-heavy pure computation.

### Gaps
- I found no maintained tutorial (2025–2026) specifically on "mlua + Neovim API from Rust". The patterns above are derived from mlua's general API and Neovim's Lua docs, not from a dedicated Neovim/mlua source.

---

## 7. Minimal complete example (Cargo.toml + lib.rs + Lua side)

### Takeaway
Three files and a copy step are enough:
- a cdylib crate with `mlua` 0.12 `["luajit","module"]`;
- a `build.rs` with the macOS link args;
- a `#[mlua::lua_module]` function returning a table;
- the built library copied to `lua/<name>.so` (or `.dll` on Windows) inside the plugin directory.

### Cited Findings
- mlua's canonical module crate: `[lib] crate-type = ["cdylib"]`, `mlua = { ..., features = ["module"] }` plus a Lua-version feature, and a macOS `build.rs`. — [tests/module/Cargo.toml](https://github.com/mlua-rs/mlua/blob/main/tests/module/Cargo.toml); [tests/module/build.rs](https://github.com/mlua-rs/mlua/blob/main/tests/module/build.rs); [tests/module/src/lib.rs](https://github.com/mlua-rs/mlua/blob/main/tests/module/src/lib.rs)
- Production analogue: [blink.cmp](https://github.com/saghen/blink.cmp/blob/main/Cargo.toml).

### Inferences
Assembled example, based on the cited patterns and not compiled here.

**Cargo.toml**
```toml
[package]
name = "novelist_native"
version = "0.1.0"
edition = "2024"

[lib]
crate-type = ["cdylib"]

[dependencies]
mlua = { version = "0.12", features = ["luajit", "module", "serde"] }
serde = { version = "1", features = ["derive"] }

[profile.release]
lto = true
codegen-units = 1
```

**build.rs**
```rust
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-cdylib-link-arg=-undefined");
        println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
    }
}
```
This uses the target OS from the env var so cross-compiling works. mlua's test uses `#[cfg(target_os = "macos")]`, which checks the *host*.

**src/lib.rs**
```rust
use mlua::prelude::*;
use serde::Deserialize;

#[derive(Deserialize, Default)]
struct Opts { #[serde(default)] min_len: usize }

fn word_count(_: &Lua, text: LuaString) -> LuaResult<usize> {
    Ok(text.to_str()?.split_whitespace().count())
}

fn long_words(lua: &Lua, (text, opts): (String, Option<LuaValue>)) -> LuaResult<Vec<String>> {
    let opts: Opts = match opts { Some(v) => lua.from_value(v)?, None => Opts::default() };
    Ok(text.split_whitespace().filter(|w| w.len() >= opts.min_len).map(str::to_owned).collect())
}

fn notify(lua: &Lua, msg: String) -> LuaResult<()> {
    let vim: LuaTable = lua.globals().get("vim")?;
    vim.get::<LuaFunction>("notify")?.call::<()>(msg)
}

struct Counter { n: i64 }
impl LuaUserData for Counter {
    fn add_fields<F: LuaUserDataFields<Self>>(f: &mut F) {
        f.add_field_method_get("n", |_, this| Ok(this.n));
    }
    fn add_methods<M: LuaUserDataMethods<Self>>(m: &mut M) {
        m.add_method_mut("incr", |_, this, by: Option<i64>| { this.n += by.unwrap_or(1); Ok(this.n) });
    }
}

#[mlua::lua_module(name = "novelist_native", skip_memory_check)]
fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let t = lua.create_table()?;
    t.set("word_count", lua.create_function(word_count)?)?;
    t.set("long_words", lua.create_function(long_words)?)?;
    t.set("notify", lua.create_function(notify)?)?;
    t.set("counter", lua.create_function(|_, ()| Ok(Counter { n: 0 }))?)?;
    Ok(t)
}
```

**Install step.** Copy the library into the plugin's `lua/` dir:
- Linux: `cp target/release/libnovelist_native.so lua/novelist_native.so`
- macOS: `cp target/release/libnovelist_native.dylib lua/novelist_native.so`
- Windows: `copy target\release\novelist_native.dll lua\novelist_native.dll`

**Lua side (`lua/novelist/init.lua`)**
```lua
local ok, native = pcall(require, "novelist_native")
if not ok then
  vim.notify("novelist: native module missing; run :NovelistBuild\n" .. native, vim.log.levels.WARN)
  return {}
end
local M = {}
function M.count_buf()
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  return native.word_count(text)
end
local c = native.counter(); c:incr(); print(c.n) -- userdata methods and fields
return M
```

Design note: wrap `require` in `pcall` so the plugin degrades gracefully when no binary is installed. blink.cmp has a pure-Lua fallback matcher for the same reason; that is documented in its repo, though I did not examine it in detail here.

### Gaps
- I did not compile this example. Treat the exact generics (for example `add_field_method_get`, and the bounds for `add_method_mut` under the new `MaybeSync` requirement) as needing a `cargo check` against 0.12.2.
