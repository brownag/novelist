# Appendix A — Rust native modules with mlua

How to put Rust inside a Neovim plugin as a LuaJIT native module using the `mlua` crate. Current as of October 2026: **mlua 0.12.2**, Neovim 0.12.x.

Everything marked ✅ was compiled and run against mlua 0.12.2 + Neovim 0.12.6 (LuaJIT 2.1) on Linux. Unmarked platform details (macOS, Windows) come from mlua's source and production plugins (blink.cmp, fff.nvim, avante.nvim) but were not run here.

## Contents

1. The model: what an mlua module is
2. Cargo setup and the four settings that must be right
3. Entry points and how `require` finds them
4. Writing functions: arguments, return values, serde, userdata, errors
5. Calling Neovim from Rust (and why you mostly shouldn't)
6. Threads and background work
7. Performance: cross the boundary rarely
8. Project structure and testing
9. Outdated tutorials: API changes 0.9 → 0.12

For shipping binaries to users, see `appendix-b-mlua-shipping.md`.

---

## 1. The model

A Neovim mlua plugin is a Rust `cdylib` that LuaJIT `dlopen`s. Its `luaopen_<name>` function receives **Neovim's own `lua_State`**, so Rust and Lua share one interpreter. Rust reaches the editor only through ordinary Lua values (`vim.api.*`), which means the binary depends only on LuaJIT's frozen Lua 5.1 C API, not on Neovim internals. **One binary per platform works across Neovim releases.** That property is why blink.cmp, fff.nvim, avante.nvim and toml-edit.lua (rocks.nvim) all use mlua.

The shape production plugins converge on:

- **Pure Rust core crate**: the algorithm, tested with `cargo test`.
- **Thin mlua glue crate**: converts Lua values ↔ Rust types, holds `static` state.
- **Lua**: UI, editor calls, config, loading the binary, and a pure-Lua fallback.

## 2. Cargo setup ✅

```toml
[lib]
crate-type = ["cdylib"]

[dependencies]
mlua = { version = "0.12", features = ["luajit", "module", "serde"] }

[profile.release]
lto = true
codegen-units = 1   # keep default panic = "unwind"
```

The four things that must be right:

| Setting | Right | Why |
|---|---|---|
| Lua feature | `luajit` | Neovim's LuaJIT is built without 5.2 compat; `luajit52` is wrong. Exactly one Lua feature is allowed. |
| Mode | `module` | Links against the LuaJIT already in `nvim`. **`vendored` + `module` is a compile error** — a second VM on Neovim's state would corrupt it. **`send` + `module` is also a compile error.** No Lua headers/libs are needed to build. |
| macOS linking | `-undefined dynamic_lookup` via `build.rs` | `lua_*` symbols resolve from `nvim` at load time. A `build.rs` travels with the crate; `.cargo/config.toml` doesn't. |
| Panic strategy | default `unwind` | mlua converts panics in Lua-called callbacks into Lua errors. `panic = "abort"` turns any panic into a dead editor. |

Optional features: `serde` (was `serialize`, deprecated), `macros` (`#[derive(UserData)]`, `#[derive(FromLua)]`), `anyhow`. mlua 0.12 needs Rust 1.88+ and edition 2024.

```rust
// build.rs — checks the target OS so cross-compiles work
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-cdylib-link-arg=-undefined");
        println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
    }
}
```

Linux needs nothing else. Windows: mlua emits `raw-dylib` imports against `lua51.dll`, which Neovim ships, so no import library is needed (unless `LUA_LIB_NAME` overrides it). musl targets need `-C target-feature=-crt-static` because a statically-linked musl cdylib can't be `dlopen`ed.

A complete, verified crate + loader is in `assets/mlua-template/`.

## 3. Entry points and `require` ✅

```rust
#[mlua::lua_module(name = "myplugin_native", skip_memory_check)]
fn module(lua: &Lua) -> LuaResult<LuaTable> { ... }
```

- Generates `extern "C-unwind" fn luaopen_myplugin_native`. Without `name`, the symbol uses the function name.
- `name` must be a Rust identifier: no dots, no dashes.
- **Neovim maps `require("a.b")` to the symbol `luaopen_a_b`** (dots → underscores; anything up to a `-` is stripped). ✅ A library at `lua/myplugin/native.so` loaded with `require("myplugin.native")` needs `name = "myplugin_native"`.
- One library can export several entry points (several `#[lua_module]` functions with different names); `package.loadlib(path, 'luaopen_other')` picks one. ✅
- Return any `IntoLua` value; by convention a table of functions. Returning `Err` makes `require` raise a Lua error.
- **`skip_memory_check`**: skips per-call allocation-limit checks that do nothing under Neovim's unlimited heap. blink.cmp and fff both use it for speed. Use it.

### File names

Cargo produces `libfoo.so` (Linux), `libfoo.dylib` (macOS), `foo.dll` (Windows, no `lib` prefix). Neovim's `require` searches `lua/<path>.so` (`.dll` on Windows) on the runtimepath; **it does not look for `.dylib`**. Two conventions:

1. Copy/rename the build output to `lua/<name>.so` on every OS (rename `.dylib` → `.so` on macOS). `require` then just works. ✅ on Linux.
2. **Preferred by fff and blink**: leave the binary where it is (`target/release/`, or a `lib/` dir the downloader writes) and load it by absolute path with `package.loadlib(path, 'luaopen_<name>')`. ✅ This avoids `package.cpath` finding a stale copy elsewhere, and lets the loader search `target/release` during development. `assets/mlua-template/lua/myplugin/native.lua` implements this with a nil-return fallback.

## 4. Writing functions ✅

Arguments and returns are typed tuples. Any `FromLuaMulti` in, any `IntoLuaMulti` out:

```rust
fn word_count(lua: &Lua, (text, opts): (LuaString, Option<LuaValue>)) -> LuaResult<usize> {
    let opts: Opts = match opts { Some(v) => lua.from_value(v)?, None => Opts::default() };
    Ok(text.to_str()?.split_whitespace().filter(|w| w.chars().count() >= opts.min_len).count())
}
t.set("word_count", lua.create_function(word_count)?)?;
```

- Multiple returns: return a tuple `(A, B)`; Lua receives two values. Use `Option<T>` for `nil`.
- `LuaString` avoids a copy when you only read; `String` converts (and errors on invalid UTF-8 — buffer text can contain arbitrary bytes, so prefer `LuaString` + `as_bytes()` when that matters).
- **serde**: `lua.from_value::<T>(value)?` turns a `setup({...})`-style table into a `#[derive(Deserialize)]` struct; `lua.to_value(&x)?` goes the other way. Great for config and structured results.
- **Userdata** for stateful objects:

```rust
struct Counter { total: usize }
impl LuaUserData for Counter {
    fn add_fields<F: LuaUserDataFields<Self>>(f: &mut F) {
        f.add_field_method_get("total", |_, this| Ok(this.total));
    }
    fn add_methods<M: LuaUserDataMethods<Self>>(m: &mut M) {
        m.add_method_mut("add", |_, this, s: LuaString| { this.total += s.to_str()?.split_whitespace().count(); Ok(this.total) });
    }
}
// Lua: local c = m.counter(); c:add("x y"); print(c.total)
```

(0.12 also offers `#[derive(UserData)]` + `#[mlua::userdata_impl]` behind `macros`.)

### Errors

- Returning `Err(LuaError::runtime("..."))` raises a normal Lua error; `pcall` catches it. Panics inside callbacks are caught too and become Lua errors.
- **Gotcha ✅: the error value Lua receives is mlua error *userdata*, not a string.** `err:match(...)` fails with "attempt to index a userdata value". Always `tostring(err)` before treating it as text (and before `vim.notify`). mlua's `__tostring` includes a Rust-side traceback, which is useful in logs; strip to the first line for user-facing messages.
- mlua catches panics only on the Lua → Rust call path. Panics in **your own threads**, `unsafe` UB, or stack overflow still kill Neovim. See §6.

## 5. Calling Neovim from Rust ✅

mlua has no Neovim API; `vim` is just a global table:

```rust
let vim: LuaTable = lua.globals().get("vim")?;
let api: LuaTable = vim.get("api")?;
let line: String = api.get::<LuaFunction>("nvim_get_current_line")?.call(())?;
```

Callbacks for `vim.schedule`, `nvim_create_autocmd`, `vim.keymap.set` are `lua.create_function(...)` values passed as arguments. Neovim's normal rules apply (no `vim.api` from fast/uv contexts without `vim.schedule`).

It works, but it's untyped, verbose, and **no faster than the same call in Lua**. The production pattern is: Lua gathers editor data (lines, cursor, options), passes it to Rust, Rust computes, Lua applies the result. Keep editor calls in Lua. (The only mlua `vim` wrapper crate, nvim-utils, is archived. If you truly need typed editor API from Rust, that's nvim-oxi's niche — see Appendix B.)

## 6. Threads and background work ✅

In module mode every `Lua`, `LuaTable`, `LuaFunction` is `!Send` — **the compiler stops you touching Lua off the main thread.** Plain mlua also has no way for a Rust thread to wake Neovim's event loop. So the pattern is **Rust threads write plain data into shared state; Lua pulls it on a timer**:

```rust
static DONE: LazyLock<Mutex<HashMap<u64, Result<usize, String>>>> = LazyLock::new(Default::default);

fn spawn(_: &Lua, text: String) -> LuaResult<u64> {          // copy data out of Lua first
    let id = NEXT.fetch_add(1, Ordering::Relaxed);
    std::thread::spawn(move || {
        let r = std::panic::catch_unwind(|| expensive(&text)).map_err(|_| "worker panicked".to_string());
        DONE.lock().unwrap().insert(id, r);
    });
    Ok(id)
}

fn poll(_: &Lua, id: u64) -> LuaResult<(Option<usize>, Option<String>)> {
    let Ok(mut done) = DONE.try_lock() else { return Ok((None, None)) };  // never block the UI
    Ok(match done.remove(&id) { Some(Ok(n)) => (Some(n), None), Some(Err(e)) => (None, Some(e)), None => (None, None) })
}
```

```lua
local id = native.spawn(text)
local timer = vim.uv.new_timer()
timer:start(10, 10, vim.schedule_wrap(function()
  local n, err = native.poll(id)
  if n or err then
    timer:stop(); timer:close()
    -- safe to touch buffers here (we're scheduled on the main loop)
  end
end))
```

Rules:

- **Never take a lock on the main thread that a worker may hold for long.** fff shipped an editor freeze from a `RwLock::read()` on the UI thread blocking behind a long reindex. Use `try_lock`/`try_read`, or swap in an `Arc` snapshot.
- `catch_unwind` in workers, and consider a panic hook that logs to a file. Without it, a worker panic or crash is a silent editor death.
- Stop the poll timer when done; bound any queue you feed into `vim.schedule` (a blocked loop + unbounded schedule backlog is a known memory leak pattern).
- Tokio is fine inside your own threads (a private runtime), never on the main thread.
- **mlua's `async` feature does not integrate with Neovim's loop.** Async Rust functions become coroutine-yielding Lua functions; nothing in Neovim polls their futures, and calling one directly errors with `attempt to yield across C-call boundary`. None of the major mlua plugins use it. `vim.async` does not exist in Neovim 0.12. Use threads + polling.
- blink.cmp's trick for short off-thread jobs: `vim.uv.new_work` runs a Lua function on a libuv worker thread with its *own* Lua state, which can `package.loadlib` the same library; Rust `static`s are shared process-wide. Only plain-data functions work there (no `vim.api`).

## 7. Performance

Every Lua → Rust call is a classic C API call that LuaJIT can't JIT-compile through, and mlua wraps fallible C API operations in protected calls. One benchmark measured iterating 10,000 Lua tables from Rust at ~14.7× slower than pure Lua. Consequences:

- **Cross the boundary rarely; do a lot per crossing.** blink.cmp pushes completion items into a Rust `static` once per source, then each keystroke sends only the query string and gets back compact arrays of indices and scores.
- Avoid walking big Lua tables from Rust. Pass strings/flat arrays, or keep the data on the Rust side.
- Small helpers that LuaJIT traces well are usually faster in Lua. Rust wins on: SIMD/fuzzy matching, file indexing, tokenizers, parsers, heavy text processing.
- Use `skip_memory_check`. Benchmark before and after with real data; don't assume.

## 8. Structure and testing

- **Workspace**: `core/` (pure Rust, no mlua, `cargo test`) + `nvim/` (cdylib glue). A crate built with `module` can't easily run `cargo test` because its `lua_*` symbols come from a host process; fff runs `cargo test --workspace --exclude fff-nvim`. In a single crate, keep logic in plain functions and unit-test those.
- **Glue tests run in Neovim**: build, then run a headless Lua test that loads the binary and exercises it (`nvim --headless --clean -l tests/native_test.lua`), as with any plugin test (see SKILL.md). Also test the fallback path with the binary absent.
- **Keep a pure-Lua fallback** or degrade gracefully: blink.cmp has a Lua matcher (`implementation = 'lua'`); avante disables the feature. Users on unusual platforms, or who skipped the build step, should get a warning, not a stack trace on startup.
- Report native status in `:checkhealth` (loaded? which path? version?).
- **Dev loop**: `cargo build --release` → `:restart` (a loaded library cannot be reloaded in a running process). Have the loader look in `target/release` so no copy step is needed.

## 9. Outdated tutorials: API changes

Most mlua + Neovim posts predate these:

| Version | Change |
|---|---|
| 0.9 | `ToLua` → `IntoLua` |
| 0.10 | **`'lua` lifetime removed** (`LuaTable<'lua>` → `LuaTable`); handles are `'static` (weak refs to the state), so you can store a `LuaFunction` in a struct. `get::<_, T>` → `get::<T>`. `Owned*` types removed. `TableExt`/`AnyUserDataExt` → `ObjectLike`. `send` disallowed in module mode. |
| 0.11 | `serialize` feature → `serde`. `set_metatable` fallible. |
| 0.12 | Root re-exports moved into submodules (prelude unchanged). Userdata types need `MaybeSync`. `#[derive(UserData)]`/`#[userdata_impl]` added. |

A `RegistryKey` is not freed on drop; call `lua.remove_registry_value(key)` (or `expire_registry_values`) when you're done.
