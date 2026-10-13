# Rust Neovim plugins using mlua: pitfalls, concurrency/async, testing, and alternatives

Scope note: current as of 2026-10-11. mlua's latest release is 0.12.2 (2026-10-03). Real-world references examined directly from their source (shallow clones, Oct 2026): fff.nvim (mlua 0.11.1, `module`+`luajit`), blink.cmp (mlua 0.11.3, `module`+`luajit`), avante.nvim (mlua 0.12.1, `module`+`serialize`), nvim-rs (0.9.2). nvim-oxi detail is in the earlier report and is not repeated here.

## 1. Threading: getting background Rust work back onto Neovim's main thread

### Takeaway
In Neovim, an mlua module runs in **module mode** on Neovim's own `lua_State`. That state is single-threaded, and mlua **disables the `send` feature in module mode**. So every `Lua`/`Function`/`Table` handle stays on the main thread. Background work runs in plain Rust threads (`std::thread`, a private tokio runtime) that own only Rust data, keep it in `static` `Mutex`/`RwLock`/`LazyLock` state or channels, and hand results back when Lua *pulls* them: polling from a `vim.uv` timer, a blocking wait with a timeout, or a `vim.schedule` loop. Unlike nvim-oxi, plain mlua ships no libuv binding, so a Rust thread cannot directly wake Neovim's loop.

### Cited Findings
- mlua 0.10.0-beta.2 changelog: "Disabled `send` feature in module mode (since we don't have exclusive access to Lua)." In non-module mode, 0.10 made "Lua types truly `Send` and `Sync` (when enabling `send` feature flag)", and "Futures now require `Send` bound if `send` feature is enabled." — [mlua CHANGELOG](https://raw.githubusercontent.com/mlua-rs/mlua/main/CHANGELOG.md)
- The `send` feature "makes `mlua::Lua: Send + Sync`" and adds `Send` requirements to `Function` and `UserData`. `error-send` makes `mlua::Error: Send + Sync` (added in 0.10.0, Oct 2024). — [mlua README](https://github.com/mlua-rs/mlua); [CHANGELOG](https://raw.githubusercontent.com/mlua-rs/mlua/main/CHANGELOG.md)
- Neovim docs, lua-loop: "It is an error to directly invoke `vim.api` functions (except api-fast) in `vim.uv` callbacks". The fix is `vim.schedule`/`vim.schedule_wrap`. `vim.schedule` "Schedules {fn} to be invoked soon by the main event-loop. Useful to avoid textlock or other temporary restrictions." `vim.in_fast_event()` reports whether code runs in a fast handler "where most of the API is disabled". — [Neovim :h lua](https://neovim.io/doc/user/lua/)
- Neovim docs, lua-loop-threading: "Plugins can perform work in separate (os-level) threads using the threading APIs in luv, for instance `vim.uv.new_thread`. Each thread has its own separate Lua interpreter state, with no access to Lua globals on the main thread. Neither can the editor state (buffers, windows, etc) be directly accessed from threads." Available in threads: `vim.uv` (separate loop), `vim.mpack`, `vim.json`, `require`, `print`, `vim.inspect`, pure-Lua `vim.*` utilities. — [Neovim :h lua](https://neovim.io/doc/user/lua/)
- luv's `uv.new_async` is safe to call from any thread, and the callback runs on the loop thread. That is the canonical cross-thread wake-up, though from Lua it is used as `async:send()`. — [Neovim luvref](https://neovim.io/doc/user/luvref/)
- Real-world pattern (fff.nvim, `crates/fff-nvim/src/lib.rs`): global state lives in `pub static FILE_PICKER: Lazy<SharedFilePicker>`, `FRECENCY`, and `QUERY_TRACKER` (lock-wrapped). Work is spawned with `std::thread::spawn` (4 call sites). A code comment explains a real freeze bug: calling `FILE_PICKER.read()` "on the lua/UI thread … blocks if a reindex writer is already in flight … that could freeze the nvim main loop for the entire duration of an in-progress scan. Move the check into the spawned worker so the main thread always returns instantly." Lua reads results synchronously (`is_scanning`, `wait_for_initial_scan(timeout_ms)`), and `main.lua` exposes `wait_for_index_ms` ("Block up to this many ms for the index to be ready … Set to 0 to never block"). UI updates use `vim.schedule` and `vim.uv.new_timer()` + `vim.schedule_wrap`. — [fff.nvim repo](https://github.com/dmtrKovalenko/fff.nvim) (source inspected directly)
- blink.cmp's fuzzy module keeps state in `static FRECENCY: LazyLock<RwLock<Option<FrecencyDB>>>` and `HAYSTACKS_BY_PROVIDER: LazyLock<RwLock<HashMap<..>>>`, and exposes plain synchronous functions (`set_provider_items`, `fuzzy`, `access`) via `lua.create_function`. There is no async at all; it simply makes the synchronous call fast. — [blink.cmp lua/blink/cmp/fuzzy/rust/lib.rs](https://github.com/Saghen/blink.cmp)
- nvim-oxi, by contrast, provides `libuv::AsyncHandle`. Its official pattern runs tokio on a `std::thread`, sends through an mpsc channel, calls `handle.send()`, and wraps editor calls in `schedule`. — earlier report `/home/andrew/workspace/novelist/reports/Rust Neovim plugins using nvim oxi.md`, citing [nvim-oxi examples/libuv.rs](https://github.com/noib3/nvim-oxi)
- Unbounded `vim.schedule` queues are a real risk: lualine reported a memory bug from an "unbounded vim.schedule() backlog when the main loop is blocked". — [lualine issue #1522](https://github.com/nvim-lualine/lualine.nvim/issues/1522)

### Inferences
- Recommended mlua architecture: (1) `#[mlua::lua_module]` exports thin sync functions; (2) a `start_job(args) -> job_id` function spawns a Rust thread (or submits to a `static` tokio `Runtime` built once via `OnceLock`), which writes its result into a `static Mutex<HashMap<JobId, Result>>` or an `mpsc`/crossbeam channel; (3) Lua polls with `try_take(job_id)` from a `vim.uv` timer (e.g. 10–50 ms, stopped when done) or a `vim.defer_fn` loop, then touches the editor inside `vim.schedule`. Every Lua-side handle stays on the main thread. Only plain Rust data (`String`, `Vec`, structs, serde values) crosses threads.
- For lower latency without a timer, there are two wake-up options. A Rust thread can write a byte to a pipe or eventfd that Lua watches with `vim.uv.new_pipe():open(fd)` or `vim.uv.new_poll(fd)`. Or the module can link libuv/luv symbols itself and call `uv_async_send` on a handle. Both are possible but unsupported by mlua and untested in the sources I found. Pipe/fd watching is the more portable of the two (unverified on Windows).
- Never hold a lock on the main thread that a worker can hold for long (fff's freeze bug). Use `try_read`/`try_lock`, or snapshot data via `Arc` swap (e.g. `arc-swap`).
- Never call `lua.*` or store mlua handles in a background thread. Without the `send` feature the compiler enforces this (handles are `!Send`), which is a good safety property of module mode.
- `vim.uv.new_thread` is not useful for running Rust: it gives a separate Lua state with no editor access. Rust threads are simpler.

### Gaps
- No primary source documents a "blessed" way for an mlua module to call `uv_async_send` on Neovim's loop. Whether luv/libuv symbols are reliably exported from the `nvim` binary on all platforms is unverified (nvim-oxi reports `luv_loop` symbol failures on Termux).
- Could not find benchmarks comparing timer-poll latency with async-handle wake-up in Neovim.

## 2. mlua `async` feature and Neovim's event loop

### Takeaway
mlua's `async` support is coroutine-based: an async Rust function becomes a Lua function that yields a "pending" marker until its future is ready. It does **not** hook into Neovim's libuv loop. The host has to resume the coroutine, and in Neovim that means a `vim.schedule` or timer loop that keeps resuming it. Tokio futures also need a tokio runtime to drive their I/O. The pattern works but is clunky. Most large plugins avoid `async` and use threads with polling instead. None of the three large mlua plugins examined enable the `async` feature.

### Cited Findings
- `async` feature: "enable async/await support (any executor can be used, eg. tokio or async-std)". It works on coroutines and requires running a `Thread`. — [mlua README](https://github.com/mlua-rs/mlua)
- mlua issue #76 ("Advice: async functions and libuv", 2021): the maintainer (khvzak) explained that mlua's async support polls the future and yields a pending marker while it isn't ready, and that tokio futures must run inside a tokio runtime. The recommended pattern was to wrap the async function in `coroutine.wrap` and have `vim.schedule` repeatedly resume it ("probably the most convenient way to poll tokio futures"), possibly with `async-compat` or a static single-threaded runtime. He warned that a blocking poll loop "would cause nearly 100% cpu usage". The reporter (chipsenkbeil, of distant.nvim) closed the issue after it worked. — [mlua issue #76](https://github.com/mlua-rs/mlua/issues/76)
- A later commenter (May 2022) hit `attempt to yield across C-call boundary` when calling an async function directly from Neovim. Their workaround was the same `coroutine` + `vim.schedule` resume loop. — [mlua issue #76](https://github.com/mlua-rs/mlua/issues/76)
- Changelog async items: 0.11.0-beta.1 `AsyncThread<A,R>` → `AsyncThread<R>`; 0.11.0-beta.2 "Terminate Rust `Future` when `AsyncThread` is dropped (without relying on Lua GC)"; 0.11.3 (2025-08-30) added `Lua::yield_with` as a `coroutine.yield` replacement in async functions; 0.12.0 (2026-07-05) `Lua::current_thread` resolves implicit async threads; 0.12.2 (2026-10-03) "Fix async thread cancellation, stack cleanup, and global hook restoration when recycling threads." — [mlua CHANGELOG](https://raw.githubusercontent.com/mlua-rs/mlua/main/CHANGELOG.md)
- Neovim's own Lua API is callback-based rather than coroutine-based (noted in issue #76). A `vim.async` module was proposed upstream by lewis6991. — [neovim PR #34473](https://github.com/neovim/neovim/pull/34473)
- Feature flags in the examined plugins: fff.nvim `["module","luajit"]`, blink.cmp `["module","luajit"]`, avante.nvim `["module","serialize"]`. None uses `async`. — Cargo.toml files in [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim), [blink.cmp](https://github.com/Saghen/blink.cmp), [avante.nvim](https://github.com/yetone/avante.nvim)

### Inferences
- Async functions can only be called from inside a Lua coroutine, never directly from a keymap or autocmd callback, because that would yield across a C boundary. Each Rust future therefore needs Lua glue: a coroutine plus a `vim.schedule` or timer resume loop. Every resume runs on the main thread, so a future that does CPU work during `poll` blocks the editor.
- Since `send` is unavailable in module mode, futures passed to mlua are not required to be `Send`. But tokio I/O futures still need a runtime context, such as a `static` current-thread runtime entered during poll, or `async-compat`.
- Thread + channel + timer polling is usually simpler and more predictable. Use mlua `async` only if you want Lua code written in a coroutine style (`local r = rust.fetch(url)` inside a coroutine-based framework such as a `vim.async` or plenary-async layer).

### Gaps
- Whether Neovim's `vim.async` (PR #34473) has merged and shipped in 0.12, and how it would interact with mlua async functions: not verified.
- No production Neovim plugin using mlua `async` was found to cite as a reference.

## 3. Crashes, panics, LuaJIT limits, and memory ownership

### Takeaway
A module runs inside the `nvim` process, so any segfault, abort, or uncaught panic in a non-Lua thread can kill or destabilize the editor. mlua converts panics in Lua-called callbacks into Lua errors, but panics in your own background threads, panics in `Drop` during unwinding, `panic = "abort"`, and UB in `unsafe` code are not caught. LuaJIT on 64-bit now uses GC64 by default, so the old 2 GB Lua-heap limit only matters for unusual builds, and Rust-side allocations never counted against it. `RegistryKey`s are not freed on drop, and mlua 0.10 removed the `'lua` lifetime, so handles can now be stored in structs.

### Cited Findings
- "Panics inside Rust callbacks are wrapped as regular Lua errors" and can be resumed when propagated back to Rust. `LuaOptions` can disable panic catching in `pcall`/`xpcall`. — [mlua README](https://github.com/mlua-rs/mlua)
- mlua says it "does not provide absolute safety even without `unsafe`" and contains "a huge amount of unsafe code". Bugs it explicitly considers bugs include UB without `unsafe`, panics containing "mlua internal error", a longjmp over Rust frames, and a Lua stack leak or other misbehaviour after a user panic. Places where the Lua C API can longjmp are protected by `lua_pcall`, which has overhead. — [mlua README](https://github.com/mlua-rs/mlua)
- Module mode "uses an external Lua runtime which could lead to potential unsafety due to the unpredictability of the Lua environment and usage of libraries such as `debug`". — [mlua README](https://github.com/mlua-rs/mlua)
- Recent fixes show that panic paths are still being hardened. 0.12.2 (2026-10-03): "Fix panic and error handling in callbacks and userdata destructors to avoid corrupting Lua state" and "Prevent scoped userdata and callbacks from outliving their scope during cleanup". 0.10.4: abort when Luau userdata destructors panic. — [mlua CHANGELOG](https://raw.githubusercontent.com/mlua-rs/mlua/main/CHANGELOG.md)
- fff.nvim installs a panic hook plus a SIGSEGV chain handler at module load. The comment says: "Without this, a crash inside fff produces a silent nvim death — neovim's own handler does not log a Rust-side backtrace." The hook writes a crash report file, then calls the default hook. — [fff.nvim crates/fff-nvim/src/lib.rs, crates/fff-core/src/log.rs](https://github.com/dmtrKovalenko/fff.nvim)
- Binary replacement while loaded: fff.nvim downloads to `binary_path .. '.tmp'`, verifies it, then `fs_rename`s it over. "On Windows the old .dll may be locked by the current process, so rename can fail if fff is already loaded". The `.tmp` is then promoted on the next start, with the message "please restart Neovim to apply the update". — [fff.nvim lua/fff/download.lua](https://github.com/dmtrKovalenko/fff.nvim)
- Load failures from ABI/arch mismatch are a common support issue. A blink.cmp discussion shows a "symbol not found" error when the fuzzy module loads, and the fix was deleting and rebuilding/refetching the library and checking it with `ldd`. — [blink.cmp discussion #2299](https://github.com/saghen/blink.cmp/discussions/2299)
- LuaJIT install docs: "All LuaJIT 64 bit ports use 64 bit GC objects by default". The old 32-on-64 mode is opt-in on x64 via `-DLUAJIT_DISABLE_GC64`. — [LuaJIT install](https://luajit.org/install.html). Non-GC64 x64 builds limit GC memory to the low 2 GB address space. — [OpenResty: LuaJIT GC64 mode](https://blog.openresty.com/en/luajit-gc64-mode/)
- `RegistryKey` "is not automatically garbage collected on Drop, but it can be removed with `Lua::remove_registry_value`". Instances not removed manually can be collected with `Lua::expire_registry_values`. The docs warn that "it is easy to accidentally cause reference cycles that the Lua garbage collector cannot resolve" and recommend `AnyUserData::set_user_value` over storing a `RegistryKey` inside `UserData`. — [docs.rs RegistryKey](https://docs.rs/mlua/latest/mlua/struct.RegistryKey.html)
- Lifetime changes: 0.10.0-beta.1 "Dropped `'lua` lifetime (subtypes now store a weak reference to Lua)", and `UserDataMethods`/`UserDataFields` lost their lifetimes in beta.2. In 0.11, `Lua::scope` passes `&Scope`, and in 0.12.0-rc.1 `BorrowedStr`/`BorrowedBytes` lost their lifetimes. — [mlua CHANGELOG](https://raw.githubusercontent.com/mlua-rs/mlua/main/CHANGELOG.md)

### Inferences
- Crash hygiene checklist:
  - Keep the default `panic = "unwind"` in the cdylib profile. With `abort`, mlua's conversion of callback panics into Lua errors cannot work.
  - Wrap each background-thread body in `std::panic::catch_unwind` and turn panics into an error result for Lua to poll.
  - Handle poisoned locks (`.read().ok()` as fff does, or `parking_lot`).
  - Install a panic hook that logs to `stdpath('log')`.
  - Avoid `unsafe` FFI to Neovim's C symbols, which is nvim-oxi territory.
- Native libraries cannot be unloaded or reloaded in a running Neovim (`package.loaded` reset does not `dlclose`). Development loops need an editor restart. Overwriting a mapped `.so` in place, rather than renaming over it, risks crashes, so build to a temp path and rename. On Windows, plan for the locked-DLL case.
- Since 0.10 removed the `'lua` lifetime, `Function`/`Table` handles can be stored in `static` thread-local or `RefCell` state on the main thread, e.g. to keep a Lua callback. They keep the value alive through the registry. Clear them explicitly (e.g. on `VimLeavePre`, or when a job finishes) to avoid leaks. `RegistryKey` is the explicit form of this and needs `remove_registry_value`.
- Because Neovim's LuaJIT and Rust heaps are separate, large data (indexes, ASTs) should stay in Rust and be returned to Lua as small slices. That avoids GC pressure in LuaJIT on any build.
- The C stack is a lesser concern. Deep Lua↔Rust recursion (Lua calls Rust calls Lua …) consumes C stack on the main thread. mlua's protected calls add frames. There is no documented Neovim-specific limit.

### Gaps
- I found no documented incidents of mlua-specific segfaults in Neovim (searches returned only generic docs). Crash evidence comes from fff.nvim's defensive code, not from incident reports.
- Whether Neovim's official release builds use GC64 on every platform (as LuaJIT's default implies) is not confirmed from Neovim's build files. Distro builds against system LuaJIT or PUC Lua 5.1 may differ.

## 4. Performance: crossing the Lua↔Rust boundary

### Takeaway
Each call from LuaJIT into an mlua function is a classic `lua_CFunction` call. LuaJIT cannot compile it into a trace and only "stitches" around it. mlua also adds protection overhead on every C API operation that may raise an error. Iterating Lua tables element by element from Rust can be about 15x slower than doing it in LuaJIT. Rust pays off when there is a lot of work per call (fuzzy-matching thousands of items, parsing, indexing, regex, tokenizing), when data stays on the Rust side, and when crossings are few and batched. Use `skip_memory_check` in module mode.

### Cited Findings
- LuaJIT NYI table: `FUNCC`/`FUNCCW` (call C function via classic API) are "2.1 stitch". Trace stitching lets a trace "stop at a classic C function", return to the interpreter, run it, and start a new trace. This "is not particularly efficient, but it avoids trace aborts". — [LuaJIT NYI list (Tarantool wiki mirror)](https://github.com/tarantool/tarantool/wiki/LuaJIT-Not-Yet-Implemented)
- mlua issue #318 (Oct 2023): summing a field across 10,000 tables from Rust took about 14.7x longer than pure Lua (0.00559 s vs 0.00038 s average). The maintainer explained that module mode adds safety checks (e.g. allocation success) and suggested `#[mlua::lua_module(skip_memory_check)]`, which "significantly improves performance". He also said mlua uses the public Lua API while the VM uses faster internals, and that mlua protects each `lua_next` call during table iteration. — [mlua issue #318](https://github.com/mlua-rs/mlua/issues/318)
- blink.cmp: "NOTE: skip_memory_check greatly improves performance" above `#[mlua::lua_module(skip_memory_check)]`. fff.nvim uses the same attribute, citing issue #318. avante.nvim does not. — [blink.cmp lib.rs](https://github.com/Saghen/blink.cmp); [fff.nvim lib.rs](https://github.com/dmtrKovalenko/fff.nvim); [avante.nvim crates](https://github.com/yetone/avante.nvim)
- blink.cmp's design (`set_provider_items` once, then `fuzzy(...)` per keystroke) keeps the haystack resident in a Rust `static`, so per-keystroke calls only pass the query and return indices and scores. — [blink.cmp lib.rs](https://github.com/Saghen/blink.cmp)
- The "FFI sandwich" (LuaJIT FFI → C → Lua C API → VM) is unsupported in LuaJIT. Re-entering the VM from an FFI-called C function while machine code is running can panic the process. — [Tarantool LuaJIT patch thread](https://lists.tarantool.org/pipermail/tarantool-patches/2020-April/015536.html)

### Inferences
- Batching rules:
  - Keep large state in Rust and push it once (or incrementally).
  - Return compact results: arrays of indices or numbers instead of tables of tables.
  - Avoid per-item callbacks from Rust into Lua.
  - Prefer `serde`/`LuaSerdeExt` (`lua.from_value`/`to_value`) for one-shot bulk conversion, which is still O(n) protected operations, over hand-written per-field `get` calls in hot loops.
  - Use `BorrowedStr`/`&[u8]` to avoid string copies.
- Pure-Lua code that LuaJIT compiles well (numeric loops, small string ops) will often beat an mlua call. Do not move small helpers to Rust. Rust wins on algorithmic heavy lifting, multithreading (rayon in a background thread), and mature crates such as tree-sitter, regex, tokenizers, git2, and HTTP.
- A Rust module called through LuaJIT's `ffi` (`extern "C"` functions plus `ffi.cdef`) avoids the classic-API cost. FFI calls are JIT-compiled, but you lose mlua's safety and type conversion. It is an option for very hot, primitive-typed calls, but must never re-enter Lua (the "FFI sandwich").

### Gaps
- No up-to-date (2025–2026) benchmark of per-call overhead (ns per call) for mlua vs nvim-oxi vs LuaJIT FFI inside Neovim was found.

## 5. Testing: Rust unit tests, headless Neovim integration, CI

### Takeaway
The common production pattern is to split the code. Put the logic in a pure Rust crate that is tested with ordinary `cargo test`, and keep the mlua `cdylib` glue thin. Integration-test the glue in headless Neovim, via `nlua` + `busted`, or plenary's `PlenaryBustedDirectory` under `nvim --headless`. A `module`-feature crate is awkward to `cargo test` directly, because its `lua_*` symbols are meant to resolve from the host process at load time.

### Cited Findings
- fff.nvim CI runs `cargo test … --workspace --exclude fff-nvim --exclude fff-python`, which excludes the mlua binding crate. It also runs stress tests (`make test-stress-seeded/random/regressions`), clippy, and fmt, and builds core crates for i686 with zig. Lua tests use plenary: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"`. Lua CI downloads a pinned Neovim (v0.11.5) tarball and runs lua-language-server type checks and luacheck. — [fff.nvim .github/workflows/rust.yml, lua.yml, tests/minimal_init.lua](https://github.com/dmtrKovalenko/fff.nvim)
- avante.nvim's `make luatest` runs `scripts/run-luatest.sh`. It requires `nlua` and `busted`, isolates `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_STATE_HOME` under `target/tests/nvim`, and uses a `tests/nlua_helper.lua` that prepends the cwd to `runtimepath`. CI runs on ubuntu-24.04 and macos-latest via a Nix dev shell, with a separate `build-libraries` matrix and a `rust.yaml` workflow. Its Rust crates expose `lua51`/`lua52`/`lua53`/`lua54`/`luajit` features that map to `mlua/*`, so they can be built against a standalone Lua. — [avante.nvim .github/workflows/tests.yaml, Makefile, scripts/run-luatest.sh, crates/*/Cargo.toml](https://github.com/yetone/avante.nvim)
- Module-mode builds "don't need Lua binaries or headers installed". On Linux the `lua_*` symbols resolve at load time. macOS needs `-undefined dynamic_lookup`. On Windows the module links against `lua5x.dll` (for Neovim, `lua51.dll`). — [mlua README](https://github.com/mlua-rs/mlua)
- Symbol resolution failures appear when the host Lua is statically linked and doesn't export its symbols (`undefined lua_pushlstring` when loading a C module with vendored Lua). — [mlua issue #524](https://github.com/mlua-rs/mlua/issues/524)
- nvim-rs tests need a real Neovim binary via `NVIMRS_TEST_BIN`. — [nvim-rs README](https://github.com/KillTheMule/nvim-rs)

### Inferences
- Suggested layout:
  - `core/` is a pure Rust crate with no mlua, unit-tested and benchmarked with criterion.
  - `nvim/` is the cdylib with `mlua` and `["module","luajit"]`.
  - Optionally, a test-only feature swaps `module` for `["luajit","vendored"]`, so `cargo test -p nvim --no-default-features --features test-vendored` can create a standalone `Lua::new()`, `require` the exported table via the same `create_exports(lua)` function, and assert on results. This checks the conversion glue without Neovim. fff's `create_exports(lua)`, separate from `#[lua_module]`, is the right shape for that.
- Integration: build with `cargo build --release`, put `target/release` on `package.cpath` (or copy to `lua/<name>.so`), then run busted under `nlua` (Neovim as the Lua interpreter) or plenary in `nvim --headless`. Isolate XDG dirs, and test against a matrix of Neovim versions (stable and nightly). mlua is not coupled to Neovim's C ABI, but the Lua-side `vim.*` usage is.
- CI should build artifacts per target triple (Linux glibc/musl, macOS arm64/x86_64, Windows MSVC). Both blink.cmp and fff ship prebuilt binaries with a download step, because users often lack a Rust toolchain. fff requires nightly to build from source.

### Gaps
- I did not verify a public example that runs `cargo test` against the mlua glue crate with `vendored` LuaJIT. The approach is inferred from mlua's feature flags.

## 6. Comparison: mlua vs nvim-oxi vs RPC (nvim-rs / msgpack child process)

### Takeaway
- **mlua module** is the pragmatic default for "Rust compute kernel + Lua frontend". It has no coupling to Neovim's C ABI (only to LuaJIT's stable 5.1 C API), mature releases (0.12.2, Oct 2026), and production use in blink.cmp, avante.nvim, and fff.nvim. Neovim API access is dynamic and untyped (`vim.api.*` through Lua tables), and you write Lua glue.
- **nvim-oxi** adds typed, direct `nvim_*` C calls and a libuv `AsyncHandle`. In exchange, binaries are tied to a Neovim minor version, and 0.12 support is git-only (see the earlier report). It also exposes `nvim_oxi::mlua::lua()` for interop.
- **RPC** (nvim-rs, a `jobstart`/`vim.system` child speaking msgpack) gives full process isolation, so a crash cannot take down the editor. It gives real async (tokio), and the API is auto-generated from metadata. In exchange, every call is an IPC round-trip, keymaps and autocmd callbacks need Lua shims, and there is a process lifecycle to manage.

### Cited Findings
- nvim-oxi motivation: RPC forces everything through MessagePack serialization, "prohibiting things like attaching callbacks to keymaps or scheduling functions". nvim-oxi hooks "straight into the Neovim C code". — [nvim-oxi README](https://github.com/noib3/nvim-oxi) (via earlier report)
- From the earlier report: nvim-oxi's typed option structs mirror Neovim's internal `#[repr(C)]` keysets, so a binary is tied to one Neovim minor version. crates.io 0.6.0 (May 2025) supports only 0.10/0.11, and 0.12 support is on git `main`. The large Rust-backed plugins use mlua module mode instead. — `/home/andrew/workspace/novelist/reports/Rust Neovim plugins using nvim oxi.md`
- mlua's crate versions in production (Oct 2026): avante.nvim `0.12.1`, blink.cmp `0.11.3`, fff.nvim `0.11.1`. — Cargo.toml in [avante.nvim](https://github.com/yetone/avante.nvim), [blink.cmp](https://github.com/Saghen/blink.cmp), [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim)
- mlua supports lua51–lua55, luajit/luajit52, and luau. Module mode builds a `cdylib` with no Lua headers needed. — [mlua README](https://github.com/mlua-rs/mlua)
- nvim-rs: version 0.9.2 (docs.rs dated 2025-07-26), README says "The **API** is unstable", fork of neovim-lib, LGPL-3.0. Features are `use_tokio` and `use_smol` (async-std replaced by smol in the current Cargo.toml). Connection constructors in `create::tokio`: `new_tcp`, `new_path` (socket), `new_child`, `new_child_path`, `new_child_cmd`, `new_child_handshake_cmd`, `new_parent` (stdio, for being spawned by Neovim). Plugins implement `Handler` with `async fn handle_request(&self, name, args: Vec<rmpv::Value>, neovim) -> Result<Value, Value>` (and `handle_notify`). The API module is "The auto generated API for neovim", produced by `bindings/generate_bindings.py`. — [docs.rs nvim-rs](https://docs.rs/nvim-rs/latest/nvim_rs/); [nvim-rs repo](https://github.com/KillTheMule/nvim-rs) (source inspected: Cargo.toml, src/create/tokio.rs, examples/basic.rs)
- nvim-rs example comment: "Any error should probably be logged, as stderr is not visible to users." — [nvim-rs examples/basic.rs](https://github.com/KillTheMule/nvim-rs)
- Neovim remote-plugin docs: remote plugins are "coprocesses that have a direct communication channel" with Nvim. Plain `rpcrequest()`/`rpcnotify()` programs work, but the docs suggest a language plugin host. You "must execute :UpdateRemotePlugins every time a remote plugin is installed, updated, or deleted". `sync` handlers use `rpcrequest` (blocking), and others use `rpcnotify` (fire-and-forget). — [Neovim :h remote-plugin](https://neovim.io/doc/user/remote_plugin/)

### Comparison table (synthesized from the findings above)

| Dimension | mlua (module) | nvim-oxi | RPC child (nvim-rs / rmpv) |
|---|---|---|---|
| Process model | in-process cdylib, Neovim's `lua_State` | in-process cdylib, direct C API | separate process, msgpack over stdio or socket |
| Neovim API access | dynamic via Lua (`lua.globals()` → `vim.api.*`), untyped, or kept in Lua glue | typed Rust API with builders; `call_function`/`exec2` escape hatches; can drop to mlua | auto-generated async API covering all of `nvim_*`, but values are `rmpv::Value` |
| Callbacks (keymap, autocmd) | yes, Rust closures via `create_function` | yes, typed | no direct callbacks; Lua shim → `rpcnotify` |
| Version coupling | LuaJIT/Lua 5.1 C API only (very stable); `vim.*` semantics at the Lua level | Neovim minor version (struct layouts) | msgpack API metadata (stable, versioned API levels) |
| Async | threads + polling; `async` feature needs coroutine/schedule glue; no `send` in module mode | `libuv::AsyncHandle` + tokio thread | native tokio/smol; nested requests |
| Crash isolation | none, crash kills nvim | none | full; child can be restarted |
| Per-call latency | function-call cost (stitched C call, plus protection overhead) | similar or lower (direct C) | IPC round-trip and serialization |
| Build/distribution | cdylib per platform; macOS `dynamic_lookup`; Windows links `lua51.dll` | cdylib + version feature + linker flags (see earlier report) | normal executable; easiest to cross-compile; must locate and spawn the binary |
| Maturity (Oct 2026) | mlua 0.12.2, widely used | crates.io 0.6.0 (May 2025), 0.12 git-only | nvim-rs 0.9.2 (2025), "API is unstable" |

### Inferences
- Choose **mlua** when Rust is a compute/data backend (fuzzy matching, parsing, indexing, tokenizing, templating) behind a Lua UI, and when you want one binary to work across Neovim 0.10–0.12+ without rebuilds. The Lua glue is a feature: UI and editor API calls stay in idiomatic Lua, and Rust only sees plain data.
- Choose **nvim-oxi** when most logic must drive the editor API from Rust with types, and you can pin a Neovim minor version and a git revision. Its `mlua` feature allows a mixed approach.
- Choose **RPC** when isolation matters (untrusted or crash-prone native deps, long-running servers, network I/O), when the same backend should serve other editors or CLIs (fff also ships `fff-mcp` and `fff-python` crates alongside `fff-nvim`), or when you want idiomatic tokio without bridging to the editor loop. Avoid it for per-keystroke hot paths. Modern practice spawns the child from Lua with `vim.fn.jobstart(cmd, {rpc = true})` or a socket instead of the legacy `rplugin` manifest and `:UpdateRemotePlugins` flow (inferred, not stated in the docs page fetched).
- Hybrid designs are common in spirit: an mlua module for hot sync paths, plus a background Rust thread or child process for slow work.

### Gaps
- No primary source quantifies the RPC round-trip latency of nvim-rs against an in-process call.
- I could not confirm from the fetched Neovim docs page whether `:h remote-plugin` is formally deprecated in 0.12. The page fetched contained no deprecation notice.
- nvim-rs's commit activity after 0.9.2 was not fully audited. A shallow clone showed a latest commit dated 2026-06-13 ("Update CI").
