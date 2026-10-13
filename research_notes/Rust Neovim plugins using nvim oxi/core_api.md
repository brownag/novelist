# nvim-oxi: Core Architecture and API Surface (as of October 2026)

Research date: 2026-10-11. Primary sources: the GitHub repo (main branch as of the latest commit dated 2026-05-17), the `v0.6.0` git tag, crates.io, and docs.rs. I downloaded both the `main` and `v0.6.0` source archives and read them directly. Code below is quoted verbatim from the repo unless marked **[illustrative]**.

**Version caveat that applies throughout.** The latest release on crates.io is still **0.6.0 (2025-05-23)**. Since then `main` has collected about a year of unreleased breaking changes, including new Neovim feature flags, the removal of `neovim-0-10`, and MSRV 1.91. The CHANGELOG mislabels some of these as 0.6.0. Each fact below says whether it applies to **0.6.0 (crates.io)** or **main (git, unreleased)**.

---

## 1. What nvim-oxi is and how it works (FFI vs RPC)

### Takeaway
nvim-oxi provides in-process Rust bindings to Neovim. Your crate compiles to a `cdylib`, which Neovim's LuaJIT loads through `require("name")` as a native Lua C module. Its `luaopen_<name>` symbol captures the `lua_State*`. From then on, Rust calls Neovim's exported C API functions (`nvim_*`) and the LuaJIT C API directly. There is no msgpack-RPC layer, so callbacks for keymaps, autocmds, `schedule`, and so on work as they do in Lua.

### Cited Findings
- The README describes the crate as "safe and idiomatic Rust bindings to the rich API exposed by the Neovim text editor", "mostly intended for plugin authors, although nothing's stopping end users from writing their Neovim configs in Rust." — [README](https://github.com/noib3/nvim-oxi)
- RPC vs FFI, from the README: "The traditional way to write Neovim plugins in languages other than the 'builtin' ones, i.e. Vimscript or Lua, is via RPC channels. This approach comes with a few limitations mostly due to having to (de)serialize everything to MessagePack-encoded messages, prohibiting things like attaching callbacks to keymaps or scheduling functions. nvim-oxi takes a different approach. It leverages Rust's foreign function interface (FFI) support to hook straight into the Neovim C code, allowing feature parity with 'in process' plugins while also avoiding the need for an extra IO layer." — [README](https://github.com/noib3/nvim-oxi)
- The README gives two reasons to use it: (1) access to the Rust crate ecosystem (serde, networking, IO, green threads), and (2) "a fully typed API: everything from optional function fields to callback arguments is checked at compile-time." — [README](https://github.com/noib3/nvim-oxi)
- **Entrypoint mechanism.** The `#[nvim_oxi::plugin]` proc macro keeps your function and also emits `#[unsafe(no_mangle)] unsafe extern "C" fn luaopen_{plugin_name}(state: *mut lua::ffi::State) -> c_int { nvim_oxi::entrypoint::entrypoint(state, plugin_name) }`. That is the standard symbol LuaJIT's `require` looks for in a native module. — [crates/macros/src/plugin.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/macros/src/plugin.rs)
- `entrypoint()` runs `types::arena_init()` and `luajit::init(lua_state)`. With the `libuv` feature it also runs `libuv::init(lua_state)`. It then calls your function and pushes the return value onto the Lua stack through the `Pushable` trait. A push error is raised as a Lua error. — [src/entrypoint.rs](https://github.com/noib3/nvim-oxi/blob/main/src/entrypoint.rs)
- The Lua state pointer is stored in a `thread_local!` `OnceCell<*mut State>`. The source warns that `init` "**must** be called before calling any other function exposed by this crate or there will be segfaults". — [crates/luajit/src/state.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/state.rs)
- The bindings to Neovim's C API are `unsafe extern "C" { ... }` blocks with no link library on Unix, so symbols resolve at load time against the running `nvim` binary. On Windows MSVC they use `#[link(name = "nvim.exe", kind = "raw-dylib", modifiers = "+verbatim")]`, and LuaJIT functions link against `lua51` as `raw-dylib`. — [crates/api/src/ffi/options.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/ffi/options.rs), [crates/luajit/src/ffi.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/ffi.rs)
- Because of this, macOS builds need `-C link-arg=-undefined -C link-arg=dynamic_lookup`, "to tell the Rust linker that the FFI functions nvim-oxi links to will only be available at runtime". The repo's own `.cargo/config` also sets `/FORCE:MULTIPLE` for Windows MSVC targets. — [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md), repo `.cargo/config` (main)
- API calls pass `LUA_INTERNAL_CALL` as the channel id. This is the same pseudo-channel Neovim uses for calls coming from Lua (`VIML_INTERNAL_CALL + 1`, with the top bit set). — [crates/api/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/lib.rs)
- `schedule()` cannot call the C `nlua_schedule` directly: "Unfortunately the `nlua_schedule` C function is not exported, so we have to call the Lua function instead". It wraps the Rust closure as a Lua function and calls `vim.schedule`. — [src/toplevel.rs](https://github.com/noib3/nvim-oxi/blob/main/src/toplevel.rs)
- `nvim_oxi::print!` is implemented by calling Lua's global `print` through the LuaJIT C API. — [crates/luajit/src/macros.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/macros.rs)
- The README points to a Neovim Discourse thread, "Calling Neovim internal functions with LuaJIT FFI and Rust", for more background. — [README](https://github.com/noib3/nvim-oxi)

### Inferences
- The plugin runs on Neovim's main thread and shares its address space. A panic or UB in Rust can crash Neovim, and long-running Rust code blocks the editor. Background work has to go to other threads and come back through `libuv::AsyncHandle` plus `schedule`.
- Unlike RPC plugins (pynvim, neovim-lib, nvim-rs, etc.), there is no separate process and no serialization cost. In exchange the compiled binary is tied to the Neovim version's C ABI and option-struct layouts, which is why version feature flags are required (section 2).
- The `luaopen_<fn name>` naming means the **function name** under `#[nvim_oxi::plugin]` must match the module name passed to `require`, which in turn must match the library file name.

### Gaps
- I could not reach the referenced Discourse thread (DNS failure), so I could not quote its deeper explanation.
- I found no official statement on thread-safety guarantees beyond what the code shows (thread-local state, `!Send` handles).

---

## 2. Latest version, Neovim compatibility, and Cargo feature flags

### Takeaway
The latest published crate is **0.6.0 (2025-05-23)**. It requires exactly one of `neovim-0-10`, `neovim-0-11` or `neovim-nightly`. As of October 2026 no 0.7 has been released. **Main** has dropped `neovim-0-10`, added `neovim-0-12` (Apr 2026), and CI-tests 0.11.7, 0.12.0 and Nightly. Anyone targeting Neovim 0.12 today probably needs a git dependency on main.

### Cited Findings
- Release history on crates.io: 0.1.0 (2022-07-16), 0.2.0 (2022-10-15), 0.3.0 (2023-04-21), 0.4.0 (2023-12-10), 0.4.1 (2023-12-16), 0.4.2 (2024-01-29), 0.5.0 (2024-05-28), 0.5.1 (2024-06-23), **0.6.0 (2025-05-23)**. max_version is 0.6.0. — [crates.io API](https://crates.io/api/v1/crates/nvim-oxi), [docs.rs](https://docs.rs/crate/nvim-oxi/latest)
- **0.6.0 features (crates.io):** `neovim-0-10`, `neovim-0-11` (implies 0-10), `neovim-nightly` (implies 0-11), `libuv`, `mlua`, `test` (macros/test + cargo_metadata), `test-terminator` (test + libuv), and `__vendored_luajit` (mlua/vendored). — [crates.io API](https://crates.io/api/v1/crates/nvim-oxi), [v0.6.0 Cargo.toml](https://github.com/noib3/nvim-oxi/blob/v0.6.0/Cargo.toml)
- **0.6.0 build.rs** fails with a `compile_error!` unless one version feature is set: "You must enable one of the features: neovim-0-10, neovim-0-11, neovim-nightly". — [v0.6.0 build.rs](https://github.com/noib3/nvim-oxi/blob/v0.6.0/build.rs)
- 0.6.0 depends on `mlua = "0.10"` (with `luajit`) when the `mlua` feature is on. — [v0.6.0 Cargo.toml](https://github.com/noib3/nvim-oxi/blob/v0.6.0/Cargo.toml)
- **Main features (unreleased; workspace version still "0.6.0"):**
  ```toml
  [features]
  default = ["__no_docsrs"]
  neovim-0-11 = ["api/neovim-0-11"]
  neovim-0-12 = ["neovim-0-11", "api/neovim-0-12"]
  neovim-nightly = ["neovim-0-12", "api/neovim-nightly"]
  __docsrs = ["mlua?/vendored"]
  __no_docsrs = ["mlua?/module"]
  libuv = ["dep:libuv"]
  mlua = ["api/mlua", "dep:mlua"]
  test = ["macros/test", "dep:cargo_metadata"]
  test-terminator = ["test", "libuv", "macros/test-terminator"]
  ```
  Main uses edition 2024, `rust-version = "1.91.0"`, and `mlua = 0.11` (luajit). — [main Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- Main `build.rs`: "You must enable one of the features: neovim-0-11, neovim-0-12, neovim-nightly". — [main build.rs](https://github.com/noib3/nvim-oxi/blob/main/build.rs)
- Main commit timeline: "api: add a `neovim-0-12` feature (#295)" and "api: drop support for `neovim-0-10` (#302)" (2026-04-06). "Bump MSRV to 1.91.0" (2026-05-17). "chore: remove the `__vendored_luajit` dependency, enable `mlua/vendored` by default (#252)" (2025-05-31). "feat(api): implement `mlua::{Into,From}Lua` for `Buffer`, `Window` and `TabPage` (#276)" (2025-10-23). "chore(api): deprecate `api::notify()` (#274)" (2025-10-14). — [commits on main](https://github.com/noib3/nvim-oxi/commits/main)
- The main CI matrix runs ubuntu, macos and windows × Neovim `v0.11.7` (`--features neovim-0-11`), `v0.12.0` (`--features neovim-0-12`) and `Nightly` (`--features neovim-nightly`). — `.github/workflows/ci.yaml` on [main](https://github.com/noib3/nvim-oxi)
- What the features do: they cfg-gate signatures and the `#[repr(C)]` layouts of option structs. On main, `api::echo` returns `Result<()>` without `neovim-0-12` and `Result<EchoMessageId>` with it. Commit #301, "fix `WindowOpts`'s layout on 0.12 and Nightly", is another example. — [crates/api/src/vim.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/vim.rs), [commits](https://github.com/noib3/nvim-oxi/commits/main)
- `libuv` exposes `nvim_oxi::libuv` (bindings to Neovim's libuv event loop, obtained via `luv_loop(lua_state)`), with `AsyncHandle` and `TimerHandle`. `mlua` exposes `nvim_oxi::mlua` (a re-export of `mlua::*`) plus `nvim_oxi::mlua::lua()`, which returns an `mlua::Lua` bound to Neovim's state. `test` exposes `#[nvim_oxi::test]` and `nvim_oxi::tests::build()`. — [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs), [crates/libuv/src/loop.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/libuv/src/loop.rs)
- On main, the `mlua` feature enables `mlua?/module` by default (`__no_docsrs`). That is mlua's mode for building loadable modules that don't link their own Lua. — [main Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)

### Inferences
- **Practical guidance for Oct 2026:** with Neovim 0.11.x, `nvim-oxi = { version = "0.6", features = ["neovim-0-11"] }` from crates.io works. With Neovim 0.12.x there is no released feature flag. `neovim-nightly` on 0.6.0 targeted the 0.12 *dev* layout as of May 2025, which may not match 0.12.0 final (main had to fix `WindowOpts` layout for 0.12). So you'd use a git dependency: `nvim-oxi = { git = "https://github.com/noib3/nvim-oxi", features = ["neovim-0-12"] }`, ideally pinned to a `rev`. This is my inference and is not stated in the docs.
- A feature/runtime mismatch can be memory-unsafe because struct layouts differ, not just a missing function. Pin the feature to the Neovim version you ship for.

### Gaps
- No public roadmap or announcement for a 0.7 release turned up.
- Repo HEAD is from 2026-05-17. I couldn't verify activity from June to October 2026 beyond that.

---

## 3. Crate / module layout

### Takeaway
`nvim-oxi` is a facade over five workspace crates: `nvim-oxi-api`, `-types`, `-luajit`, `-libuv` and `-macros`. The main public surface is `nvim_oxi::{api, api::opts, api::types, lua, libuv, mlua, conversion, serde}`, the types `Object/Array/Dictionary/String/Function`, `Result/Error`, `print!/dbg!`, `schedule`, and the `plugin`/`test` macros.

### Cited Findings
- `src/lib.rs` (main) contains:
  - `pub mod api { pub use api::*; }`: "Bindings to the Neovim C API"
  - `#[cfg(feature="libuv")] pub mod libuv`
  - `pub mod lua { pub use luajit::*; }`: "Low-level Rust bindings to LuaJIT"
  - `#[cfg(feature="mlua")] pub mod mlua { pub use mlua::*; pub fn lua() -> mlua::Lua {...} }`
  - `pub use error::{Error, Result}; pub use luajit::{IntoResult, dbg, print}; pub use macros::plugin; pub use macros::test (feature test); pub use types::*; pub mod tests (feature test); pub use toplevel::*;` (`schedule`), and `pub use types::string;`
  — [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs)
- Workspace crates are `nvim-oxi-api`, `nvim-oxi-libuv`, `nvim-oxi-luajit`, `nvim-oxi-macros` and `nvim-oxi-types`. — [main Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- **Naming convention in `api`:** "All the functions have been renamed by dropping the leading `nvim_` prefix, e.g. `nvim_get_current_buf` simply becomes `get_current_buf`. Also, the functions starting with `nvim_buf_*`, `nvim_win_*` and `nvim_tabpage_*` are implemented as methods on the `Buffer`, `Window` and `TabPage` objects respectively." — [crates/api/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/lib.rs)
- `api` source modules: autocmd, buffer, command, deprecated, error, extmark, options, `pub mod opts`, tabpage, trait_utils, `pub mod types`, vim, vimscript, win_config, window. — [crates/api/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/lib.rs)
- `api::opts` (main) has option structs with builders for buf_attach, buf_delete, clear_autocmds, cmd, create_augroup, create_autocmd, create_command, decoration_provider, echo, eval_statusline, exec, exec_autocmds, get_autocmds, get_commands, get_context, get_extmark_by_id, get_extmarks, get_highlight, get_mark, get_namespace, get_text, open_term, option, parse_cmd, select_popup_menu_item, set_extmark, set_highlight, set_keymap, set_mark and win_text_height. — repo tree `crates/api/src/opts/` ([main](https://github.com/noib3/nvim-oxi/tree/main/crates/api/src/opts))
- `api::types` (main) includes `AutocmdCallbackArgs`, `CommandArgs`, `CommandNArgs`, `CommandRange`, `CommandComplete`, `CommandAddr`, `Mode`, `GotMode`, `KeymapInfos`, `LogLevel`, `WindowConfig`, `WindowRelativeTo`, `WindowAnchor`, `WindowBorder`, `WindowStyle`, `WindowTitle`, `SplitDirection`, `ExtmarkInfos`, `ExtmarkVirtTextChunk`, `HighlightInfos`, `OptionInfos`, `EchoMessageId`, `ProgressMessageStatus`, and more. — repo tree `crates/api/src/types/` ([main](https://github.com/noib3/nvim-oxi/tree/main/crates/api/src/types))
- **`types` crate exports:** `Arena`, `Array`, `Dictionary`, `KeyValuePair`, `Error`, `Function`, `NonOwning`, `Object`, `ObjectKind`, `NvimStr`, `String`, `StringBuilder`, `pub mod conversion`, `pub mod serde` (feature-gated, on by default in the facade), and `iter::{ArrayIterator, DictIter, DictIterMut, DictIterator}`. Neovim primitive aliases are `Boolean = bool`, `Integer = i64`, `Float = c_double`, `LuaRef = c_int`, and `BufHandle`/`WinHandle`/`TabHandle = c_int`. — [crates/types/src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/types/src/lib.rs)
- **Conversion traits (two layers):**
  - `nvim_oxi::conversion::{FromObject, ToObject}`, for Neovim `Object` ↔ Rust: `pub trait FromObject: Sized { fn from_object(object: Object) -> Result<Self, Error>; }` and `pub trait ToObject { fn to_object(self) -> Result<Object, Error>; }`. A conversion `Error` has variants such as `FromWrongType { expected, actual }`, `FromInt`, `FromUtf8`, `Deserialize` and `Serialize`. — [crates/types/src/conversion.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/types/src/conversion.rs)
  - `nvim_oxi::lua::{Pushable, Poppable}`, for Rust ↔ Lua stack: `unsafe fn push(self, lstate: *mut State) -> Result<c_int, Error>` and `unsafe fn pop(lua_state: *mut State) -> Result<Self, Error>`. These are what `Function::from_fn` args and returns, and the plugin entrypoint's return value, must implement. — [crates/luajit/src/pushable.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/pushable.rs), [poppable.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/poppable.rs)
  - `IntoResult<T>` (from luajit, re-exported) lets callbacks return either `T` or `Result<T, E: Error>`. — [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs)
- **`Function<A, R>`** is a typed handle to a Lua function stored in the Lua registry (`lua_ref()`). Its constructors are `from_fn` (`Fn(A) -> O` where `A: Poppable`, `O: IntoResult<R>`, `R: Pushable`), `from_fn_mut` (wraps in a `RefCell`) and `from_fn_once` (errors "Cannot call function twice"). `call(&self, args: A) -> Result<R, lua::Error>` requires `A: Pushable, R: Poppable`. `FromObject` for `Function` accepts `ObjectKind::LuaRef`. — [crates/types/src/function.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/types/src/function.rs), [conversion.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/types/src/conversion.rs)
- **Errors:** `nvim_oxi::Result<T> = Result<T, nvim_oxi::Error>`. `nvim_oxi::Error` is a `thiserror` enum with `#[from]` variants `Lua(luajit::Error)`, `Api(api::Error)`, `Nvim(types::Error)`, `ObjectConversion(conversion::Error)`, `Serialize`, `Deserialize`, `Libuv` (feature) and `Mlua` (feature). `api::Error` is `FromInt`, `FromUtf8`, `Nvim(types::Error)`, `ObjectConversion` or `Other(String)`. The `api` functions return `api::Result`, so `?` converts into `nvim_oxi::Error`. — [src/error.rs](https://github.com/noib3/nvim-oxi/blob/main/src/error.rs), [crates/api/src/error.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/error.rs)

### Inferences
- `ToObject`/`FromObject` covers the API-call path, where Neovim takes `Object`/`Dictionary` arguments. `Pushable`/`Poppable` covers the Lua-function-boundary path. Custom types crossing into Lua need both, often via serde (see the `mechanic` example, section 6).

### Gaps
- I didn't enumerate every `api` function per version. docs.rs (built with `neovim-nightly`) is the authoritative list, and its signatures may differ from what a stable feature exposes.

---

## 4. The `#[nvim_oxi::plugin]` entrypoint: return type, naming, loading

### Takeaway
Annotate a zero-argument function whose return type implements `lua::Pushable`. In practice that means `Dictionary`, `Object`, a primitive, `()`, `Function`, or a `Result<T>` of these. The function name becomes `luaopen_<name>`. The built library must be renamed to `<name>.so` (or `<name>.dll`) and placed in a `lua/` directory on `runtimepath`. `require("<name>")` then returns what the function returned.

### Cited Findings
- The macro's signature is `entrypoint<T>(lua_state, body: fn() -> T) -> c_int where T: Pushable`, so the function takes no args and returns a `Pushable`. — [src/entrypoint.rs](https://github.com/noib3/nvim-oxi/blob/main/src/entrypoint.rs)
- The macro accepts an optional `nvim_oxi = <path>` attribute (default `::nvim_oxi`) for renamed or re-exported crates. — [crates/macros/src/plugin.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/macros/src/plugin.rs)
- Official examples return `Dictionary` (`calc`, `mechanic`), `nvim_oxi::Result<Dictionary>` (`api`) and `nvim_oxi::Result<()>` (`libuv`, `mlua`). — [examples/](https://github.com/noib3/nvim-oxi/tree/main/examples)
- Artifact naming, from the official docs: if the package is `"foo"`, cargo produces `libfoo.so` (Linux), `libfoo.dylib` (macOS) or `foo.dll` (Windows). "Create a new directory named `lua` and place the compiled library inside it, renaming it to `foo.so` on Linux; `foo.so` on macOS; `foo.dll` on Windows (i.e. no renaming)." Then "add *the parent directory* of `lua` to the runtimepath, for example with `:set rtp+=~/foobar`" and run `print(require("foo")) -- prints 42`. — [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- The macro was renamed from `nvim_oxi::module` to `nvim_oxi::plugin` in 0.5.0 (#142). — [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)

### Inferences
- Note that macOS also needs the `.so` extension, because LuaJIT's `package.cpath` defaults use `?.so`.
- The library basename (for example after `lib` is stripped), the `require` string and the `#[plugin]` fn name must all agree, or LuaJIT won't find `luaopen_<name>`.

### Gaps
- The examples README still says `nvim-oxi = "0.3"` in its Cargo.toml snippet. It is stale; use 0.6 or git main.

---

## 5. How-to: commands, keymaps, autocmds, buffers/windows, Lua interop, errors, printing, schedule

### Takeaway
Each Neovim API call is a typed Rust function taking an `opts` struct built with `XxxOpts::builder()...build()`. Callbacks are Rust closures converted to `Function`s and stored in the Lua registry. Rust functions are exposed to Lua by returning them in a `Dictionary` from the entrypoint, and Lua functions passed in arrive as typed `Function<A, R>`.

### Cited Findings (signatures from main unless noted; also present in 0.6.0 with noted differences)

**User commands.** `pub fn create_user_command<Cmd>(name: &str, command: Cmd, opts: &CreateCommandOpts) -> Result<()> where Cmd: StringOrFunction<CommandArgs, ()>` takes either a Vimscript string or a Rust closure receiving `CommandArgs`. The fields are `args: Option<String>`, `bang: bool`, `count: Option<u32>`, `fargs: Vec<String>`, `line1`, `line2`, `mods`, `range: u8`, `register`, `smods`. Buffer-local versions are methods on `Buffer`. — [crates/api/src/command.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/command.rs), [types/command_args.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/types/command_args.rs)
```rust
// examples/api.rs (verbatim)
let opts = CreateCommandOpts::builder()
    .bang(true)
    .desc("shows a greetings message")
    .nargs(CommandNArgs::ZeroOrOne)
    .build();

let greetings = |args: CommandArgs| {
    let who = args.args.unwrap_or("from Rust".to_owned());
    let bang = if args.bang { "!" } else { "" };
    print!("Hello {}{}", who, bang);
};

api::create_user_command("Greetings", greetings, &opts)?;
```
— [examples/api.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/api.rs)

**Keymaps.** `pub fn set_keymap(mode: Mode, lhs: &str, rhs: &str, opts: &SetKeymapOpts) -> Result<()>` sets a global keymap. Buffer-local maps use `Buffer::set_keymap`. `SetKeymapOpts::builder().callback(f)` takes `F: ToFunction<(), ()>` and `.desc(..)`, plus `expr`, `replace_keycodes` and others. `del_keymap(mode, lhs)` and `get_keymap(mode)` also exist. — [crates/api/src/vim.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/vim.rs), [opts/set_keymap.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/opts/set_keymap.rs)
```rust
// examples/api.rs (verbatim): remaps `hi` to `hello` in insert mode
api::set_keymap(Mode::Insert, "hi", "hello", &Default::default())?;
```

**Autocommands.** `create_autocmd<'a, I: IntoIterator<Item=&'a str>>(events: I, opts: &CreateAutocmdOpts) -> Result<u32>`. The related functions are `create_augroup(name, &CreateAugroupOpts) -> Result<u32>`, `del_autocmd`, `del_augroup_by_id/by_name`, `clear_autocmds`, `exec_autocmds` and `get_autocmds`. `CreateAutocmdOpts` builder methods are `buffer(Buffer)`, `callback(F: Into<Function<AutocmdCallbackArgs, ShouldDeleteAutocmd>>)` where `ShouldDeleteAutocmd = bool` (return `true` to delete the autocmd), `command`, `desc`, `group(StringOrInt)`, `nested`, `once` and `patterns(iter)`. `AutocmdCallbackArgs` has the fields `buffer: Buffer`, `data: Object`, `event: String`, `file: PathBuf`, `group: Option<u32>`, `id: u32`, `r#match: String`. — [crates/api/src/autocmd.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/autocmd.rs), [opts/create_autocmd.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/opts/create_autocmd.rs), [types/autocmd_callback_args.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/types/autocmd_callback_args.rs)
```rust
// [illustrative] assembled from the signatures above; not from an official example
let group = api::create_augroup("MyPlugin", &CreateAugroupOpts::builder().clear(true).build())?;
let opts = CreateAutocmdOpts::builder()
    .group(group)
    .patterns(["*.rs"])
    .desc("log writes")
    .callback(|args: AutocmdCallbackArgs| {
        nvim_oxi::print!("wrote {}", args.file.display());
        false // don't delete the autocmd
    })
    .build();
api::create_autocmd(["BufWritePost"], &opts)?;
```

**Buffers and (floating) windows.** The relevant functions are `create_buf(is_listed: bool, is_scratch: bool) -> Result<Buffer>`, `open_win(buf: &Buffer, enter: bool, config: &WindowConfig) -> Result<Window>` (same in 0.6.0), and `Window::{get_config, set_config, close(self, force), hide, set_buf, get_cursor, set_cursor, set_height/width, set_hl_ns, call, is_valid, handle}`. There are also `Buffer::{get_lines, set_lines(range, strict, lines), set_text, set_keymap, attach, call, set_extmark, ...}`, `get_current_buf/win/tabpage`, `list_bufs/wins/tabpages`, and `set_option_value/get_option_value(name, &OptionOpts)`. — [crates/api/src/window.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/window.rs), [win_config.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/win_config.rs), [buffer.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/buffer.rs), [options.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/options.rs)
```rust
// examples/api.rs (verbatim excerpt): floating window toggled from Lua
let buf = api::create_buf(false, true)?;
let win: Rc<RefCell<Option<Window>>> = Rc::default();
let w = Rc::clone(&win);

let open_window: Function<(), Result<(), api::Error>> =
    Function::from_fn(move |()| {
        if w.borrow().is_some() {
            api::err_writeln("Window is already open");
            return Ok(());
        }
        let config = WindowConfig::builder()
            .relative(WindowRelativeTo::Cursor)
            .height(5)
            .width(10)
            .row(1)
            .col(0)
            .build();
        let mut win = w.borrow_mut();
        *win = Some(api::open_win(&buf, false, &config)?);
        Ok(())
    });

let close_window = Function::from_fn(move |()| {
    if win.borrow().is_none() {
        api::err_writeln("Window is already closed");
        return Ok(());
    }
    let win = win.borrow_mut().take().unwrap();
    win.close(false)
});

let api = Dictionary::from_iter([
    ("open_window", open_window),
    ("close_window", close_window),
]);
Ok(api)
```
From Lua you'd call `require("api").open_window()`. — [examples/api.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/api.rs)

**Exposing Rust functions to Lua, and calling Lua functions from Rust.**
```rust
// examples/calc.rs (verbatim)
use nvim_oxi::{Dictionary, Function, Object};

#[nvim_oxi::plugin]
fn calc() -> Dictionary {
    let add = Function::from_fn(|(a, b): (i32, i32)| a + b);
    let multiply = Function::from_fn(|(a, b): (i32, i32)| a * b);
    let compute = Function::from_fn(
        |(fun, a, b): (Function<(i32, i32), i32>, i32, i32)| {
            fun.call((a, b)).unwrap()
        },
    );
    Dictionary::from_iter([
        ("add", Object::from(add)),
        ("multiply", Object::from(multiply)),
        ("compute", Object::from(compute)),
    ])
}
```
```lua
local calc = require("calc")
print(calc.add(1, 41))
print(calc.compute(function(a, b) return a + b; end, 1, 41))  -- Lua callback invoked from Rust
```
Lua arguments arrive as a tuple that implements `Poppable`. A Lua function passed in is received as `Function<(i32, i32), i32>` and invoked with `.call(..)`. — [examples/calc.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/calc.rs), [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- Other ways to reach Lua or Vimscript from Rust: `api::call_function(func: &str, args) -> Result<Ret>`, `api::call_dict_function`, `api::command(&str)`, `api::eval<V>(expr)` and `api::exec2(src, &ExecOpts)`. With the `mlua` feature you can also use `nvim_oxi::mlua::lua().globals()...`. — [crates/api/src/vimscript.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/vimscript.rs), [src/lib.rs](https://github.com/noib3/nvim-oxi/blob/main/src/lib.rs)

**Errors.** Return `nvim_oxi::Result<T>` and use `?` on `api::*` calls. An `Err` returned from the entrypoint or from a `Function` callback becomes a Lua error, because `entrypoint` calls `luajit::utils::push_error`. `api::err_writeln(&str)` and `err_write` write to the error area. — [src/entrypoint.rs](https://github.com/noib3/nvim-oxi/blob/main/src/entrypoint.rs), [crates/api/src/vim.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/vim.rs)

**Print/notify/echo.**
- `nvim_oxi::print!(...)` works like `std::print!` and calls Lua `print`. `nvim_oxi::dbg!` also exists. — [crates/luajit/src/macros.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/luajit/src/macros.rs)
- `api::echo(chunks: impl IntoIterator<Item=(Text, Option<HlGroup>)>, history: bool, opts: &EchoOpts)` returns `Result<()>` in 0.6.0 and on main with `neovim-0-11`. On main with `neovim-0-12` or nightly it returns `Result<EchoMessageId>`. — [v0.6.0 vim.rs](https://github.com/noib3/nvim-oxi/blob/v0.6.0/crates/api/src/vim.rs), [main vim.rs](https://github.com/noib3/nvim-oxi/blob/main/crates/api/src/vim.rs)
- `api::notify(msg: &str, log_level: LogLevel, opts: &Dictionary) -> Result<Object>` is in 0.6.0. It was deprecated on main in Oct 2025 (#274), and I found no `fn notify` in main's source. It appears to have been removed, possibly alongside the Apr 2026 drop of 0.10 support. — [v0.6.0 vim.rs](https://github.com/noib3/nvim-oxi/blob/v0.6.0/crates/api/src/vim.rs), [commits](https://github.com/noib3/nvim-oxi/commits/main)

**schedule.** `pub fn schedule<F, R>(fun: F) where F: FnOnce(()) -> R + 'static, R: IntoResult<()>` binds `vim.schedule()`: "Schedules a callback to be invoked soon by the main event-loop. Useful to avoid textlock or other temporary restrictions." — [src/toplevel.rs](https://github.com/noib3/nvim-oxi/blob/main/src/toplevel.rs)

**libuv (threads → main thread).**
```rust
// examples/libuv.rs (verbatim excerpt)
let (sender, mut receiver) = mpsc::unbounded_channel::<i32>();
let handle = AsyncHandle::new(move || {
    let i = receiver.blocking_recv().unwrap();
    schedule(move |_| print!("Received number {i} from backround thread"));
})?;
let _ = thread::spawn(move || send_numbers(handle, sender)); // calls handle.send() from a tokio runtime
```
Timers: `TimerHandle::start(Duration::from_millis(0), Duration::from_secs(1), |timer: &mut TimerHandle| {...})` and `TimerHandle::once(Duration::from_secs(2), move || {...})`. — [examples/libuv.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/libuv.rs)

### Inferences
- Non-`Send` state shared between callbacks is held in `Rc<RefCell<..>>`, as in the api example, because everything runs on Neovim's single thread.
- Inside libuv callbacks, calling Neovim API functions directly may hit textlock or fast-event restrictions. The official example therefore wraps output in `schedule`.

### Gaps
- No official example for autocmds or keymap callbacks exists. The autocmd snippet above is illustrative and assembled from source signatures, and I did not compile it.

---

## 6. Minimal hello world and notable examples

### Takeaway
A plugin needs a `cdylib` crate, one `#[nvim_oxi::plugin]` function, a version feature flag, macOS linker flags, and a renamed library under `lua/`. The repo ships five examples: `api`, `calc`, `mechanic`, `mlua` and `libuv`. There is no `counter` example in the current repo.

### Cited Findings
- Official setup (examples/README.md, version string stale at "0.3"):
  ```toml
  [lib]
  crate-type = ["cdylib"]

  [dependencies]
  nvim-oxi = "0.3"
  ```
  ```rust
  #[nvim_oxi::plugin]
  fn foo() -> i32 {
      42
  }
  ```
  macOS `.cargo/config`:
  ```toml
  [target.x86_64-apple-darwin]
  rustflags = ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"]
  [target.aarch64-apple-darwin]
  rustflags = ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"]
  ```
  ```lua
  print(require("foo")) -- prints `42`
  ```
  — [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- The current examples directory contains `api.rs`, `calc.rs`, `libuv.rs`, `mechanic.rs`, `mlua.rs` and `README.md`. The root Cargo.toml declares each as a `cdylib` `[[example]]`. `libuv` requires the `libuv` feature and `mlua` requires the `mlua` feature. — [examples/](https://github.com/noib3/nvim-oxi/tree/main/examples), [Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml)
- Example descriptions, from the README: `api` covers "commands, set keymaps and manipulate floating windows". `calc` "expose[s] your plugin's core functions to Lua". `mechanic` shows how to "deserialize Lua tables into Rust objects using serde". `mlua` shows integration with the mlua crate. `libuv` uses `nvim_oxi::libuv` "to trigger a callback registered on the Neovim thread from other threads". — [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- **mechanic (serde) pattern.** Implement `FromObject` via `Self::deserialize(nvim_oxi::serde::Deserializer::new(obj))` and `ToObject` via `self.serialize(nvim_oxi::serde::Serializer::new())`. Then implement `lua::Poppable` (`Object::pop(lstate)?` then `from_object`) and `lua::Pushable` (`to_object()?.push(lstate)`) so the type works as a `Function::from_fn(fix)` arg and return:
  ```rust
  impl lua::Poppable for Car {
      unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
          unsafe {
              let obj = Object::pop(lstate)?;
              Self::from_object(obj)
                  .map_err(lua::Error::pop_error_from_err::<Self, _>)
          }
      }
  }
  ```
  On the Lua side: `require("mechanic").fix({ manufacturer = "Tesla", miles = 69420, works = false, problem = "kills_pedestrians" })`. — [examples/mechanic.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/mechanic.rs), [examples/README.md](https://github.com/noib3/nvim-oxi/blob/main/examples/README.md)
- **mlua example (main, mlua 0.11 API):**
  ```rust
  use mlua::prelude::LuaFunction;
  use nvim_oxi::{Result, mlua, print};

  #[nvim_oxi::plugin]
  fn mlua() -> Result<()> {
      print!("Hello from nvim-oxi..");
      let lua = mlua::lua();
      let print: LuaFunction = lua.globals().get("print")?;
      print.call::<()>("..and goodbye from mlua!")?;
      Ok(())
  }
  ```
  — [examples/mlua.rs](https://github.com/noib3/nvim-oxi/blob/main/examples/mlua.rs)
- **Testing** (`test` feature): `#[nvim_oxi::test]` replaces `#[test]` and runs the body inside a Neovim spawned from the `nvim` on `$PATH`. Test names must be unique across the crate, even across modules. Integration tests must live in a separate `cdylib` crate whose `build.rs` is `fn main() -> Result<(), nvim_oxi::tests::BuildError> { nvim_oxi::tests::build() }`. Since 0.5.0, tests may return `Result<(), T>` and accept `nvim-oxi`, `cmd` and `library_path` attributes. Example from the README:
  ```rust
  #[nvim_oxi::test]
  fn set_get_del_var() {
      api::set_var("foo", 42).unwrap();
      assert_eq!(Ok(42), api::get_var("foo"));
      assert_eq!(Ok(()), api::del_var("foo"));
  }
  ```
  — [README](https://github.com/noib3/nvim-oxi), [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)

### Inferences
- A **current** hello-world `Cargo.toml` for Neovim 0.11 would use `nvim-oxi = { version = "0.6", features = ["neovim-0-11"] }`. Without a version feature the build fails with `compile_error!` (section 2), and the official README snippet omits the feature. For Neovim 0.12, use a git dependency on main with `features = ["neovim-0-12"]`. This is an inference from build.rs and Cargo.toml, not documented in the README.
- Minimal build-and-install on Linux: `cargo build --release && mkdir -p lua && cp target/release/libfoo.so lua/foo.so`, then `:set rtp+=.` and `:lua print(require("foo"))`.

### Gaps
- I found no `counter` example in the current repo. If one existed in older versions, I couldn't confirm it.
- I found no substantial third-party tutorials or blog posts. The search returned only mirrors and aggregators of the repo/docs.

---

## 7. Notable breaking changes across recent versions

### Takeaway
The big breaks were 0.5.0 (`module` renamed to `plugin`, `echo` gained an opts arg, 0.8 dropped) and 0.6.0 (`notify`/`feedkeys`/`GotMode`/highlight API reshapes). On main there is a further set of unreleased breaks: `neovim-0-10` dropped, `neovim-0-12` added, `get_mode` infallible, `Buffer::get_name` returning `String`, `OptionOpts::buffer` renamed to `buf`, `notify` deprecated or removed, and MSRV 1.91. **The CHANGELOG lists several of these main-only changes under "0.6.0" although they are not in the 0.6.0 release.**

### Cited Findings
- **0.4.1 (2023-12-16):** `ExtmarkInfos::virt_text` changed from `Option<Vec<(String, OneOrMore<String>)>>` to `Vec<ExtmarkVirtTextChunk>`. — [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- **0.5.0 (2024-05-28):** added Neovim 0.10 support. Renamed the `nvim_oxi::module` macro to `nvim_oxi::plugin` (#142). `api::echo()` now takes a third `EchoOpts` argument (#145). Dropped Neovim 0.8. Test macro improvements (#159, #164). — [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- **0.5.1 (2024-06-23):** added `handle()` on `Buffer`, `Window` and `TabPage`. Removed `SetExtmarkOptsBuilder::scoped()` and `Window::{add_ns,get_ns,del_ns}`, which were experimental in 0.10. — [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- **0.6.0 (2025-05-23)**, verified against the `v0.6.0` tag:
  - `api::echo` is generic over the highlight group type.
  - `lua_<Foo>` types were renamed to `<Foo>`.
  - `SetHighlightOptsBuilder::link()` accepts any `HlGroup`. `global_link()` was removed.
  - `api::notify()` takes `&Dictionary` instead of `&NotifyOpts` and returns `Result<Object>` (#208).
  - `Object::into_dict_unchecked` was renamed to `into_dictionary_unchecked`.
  - `Window::set_hl` was renamed to `set_hl_ns` (#220).
  - `api::feedkeys()` takes two `impl Into<NvimStr>` instead of `&str` plus `Mode` (#240).
  - `GotMode::mode` is a `ModeStr` (#241).
  - The `TitleHighlight` enum was removed.
  - Added: `String::to_str()`, the `string!` macro, `StringBuilder`, `nvim_oxi::tests::build()` (#201), `Object::as_*_unchecked[_mut]`, and nightly `WindowConfig::mouse` (#189).
  — [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)
- **CHANGELOG discrepancy (verified in source):** the CHANGELOG's 0.6.0 "Changed" section lists `get_mode()` infallible (#247), `KeymapInfos::buffer: Option<Buffer>` (#255), `Buffer::get_extmarks(impl Into<GetExtmarksNamespaceId>)` (#256), `Buffer::get_name() -> Result<nvim_oxi::String>` (#262), `OptionOpts` builder `buffer` → `buf` (#268), and the `DecorationProviderOpts` fix (#253). In the `v0.6.0` tag, however, `get_mode()` still returns `Result<GotMode>`, `get_name()` returns `Result<PathBuf>`, and `KeymapInfos::buffer` is `bool`. These commits are dated 2025-05-23 (#247, after the "Release v0.6.0" commit) through 2025-08-22 (#268). **These are unreleased changes on main.** — [v0.6.0 source](https://github.com/noib3/nvim-oxi/tree/v0.6.0), [commits](https://github.com/noib3/nvim-oxi/commits/main)
- **Unreleased on main (post-0.6.0), from commits:**
  - `neovim-0-12` feature (#295) and `neovim-0-10` dropped (#302), 2026-04-06.
  - `WindowOpts` layout fix for 0.12 and nightly (#301).
  - `api::notify()` deprecated (#274, 2025-10-14) and absent from main's source by May 2026.
  - `api::echo()`/`EchoOpts` fixed on nightly (#273), and `echo` returns `EchoMessageId` on 0.12+.
  - `mlua::{IntoLua, FromLua}` for `Buffer`/`Window`/`TabPage` (#276).
  - `SetExtmarkOpts::virt_{lines,text}` highlight group bound to `SetExtmarkHlGroup` (#275).
  - `__vendored_luajit` removed and `mlua/vendored` enabled (#252). It was later restructured into `__docsrs`/`__no_docsrs`, using `mlua/module` by default.
  - mlua bumped to 0.11, MSRV bumped to 1.86, then 1.88, then 1.91, plus edition 2024.
  The "Unreleased" changelog section is empty, so none of these are documented there. — [commits](https://github.com/noib3/nvim-oxi/commits/main), [main Cargo.toml](https://github.com/noib3/nvim-oxi/blob/main/Cargo.toml), [CHANGELOG](https://github.com/noib3/nvim-oxi/blob/main/CHANGELOG.md)

### Inferences
- Code written against crates.io 0.6.0 will likely need small fixes when moving to the next release cut from main: `get_mode` dropping `?`, `get_name` types, `OptionOpts::builder().buf(..)`, replacing `notify` (probably via `call_function`/Lua `vim.notify` or `echo`), and swapping feature flags. Projects that need Neovim 0.12 support should pin a main `rev` now.

### Gaps
- I couldn't confirm the exact commit that removed `api::notify` from main. I only verified that `fn notify` is absent from main's source tree and present in v0.6.0.
- No release date or plan for 0.7 is published.
