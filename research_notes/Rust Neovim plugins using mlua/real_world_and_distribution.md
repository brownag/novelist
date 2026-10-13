# Rust Neovim plugins using mlua: real-world examples and distribution practices

Research date: 2026-10-11. Most findings come from reading the plugins' current source on GitHub (`main` branches, fetched raw). Line-level claims point to the file they came from. The GitHub REST API rate limit ran out partway through, so I couldn't browse issue trackers much. Most findings are from code, not from discussion threads.

## Q1: Which notable plugins use mlua, and how do they structure Rust vs Lua?

### Takeaway
The main examples are blink.cmp, blink.pairs and the other blink.* plugins, fff.nvim, and avante.nvim. On the LuaRocks side there are toml-edit.lua (a dependency of rocks.nvim), tiktoken_core, decasify, and typst-lua. Three layouts are common:
- a single `cdylib` crate whose Rust lives inside the `lua/` tree (blink.cmp)
- a Cargo workspace with a dedicated `*-nvim` cdylib crate next to reusable core crates (fff, avante)
- a plain cdylib with per-Lua-version cargo features, for LuaRocks (toml-edit)

In every case the Lua side owns loading. It locates the `.so`/`.dylib`/`.dll` and calls `package.loadlib(path, 'luaopen_<name>')` directly instead of relying on `package.cpath`.

### Cited Findings
- **blink.cmp:** `Cargo.toml` defines a crate `blink-cmp-fuzzy` with `[lib] path = "lua/blink/cmp/fuzzy/rust/lib.rs"`, `crate-type = ["cdylib"]`, and `mlua = { version = "0.11.3", features = ["module", "luajit"] }`. The fuzzy matching algorithm comes from the separate `frizbee` crate (`frizbee = "0.9.0"`). Rust sits in the same directory tree as the Lua wrapper. — [blink.cmp Cargo.toml](https://github.com/Saghen/blink.cmp/blob/main/Cargo.toml)
- blink.cmp keeps a pure-Lua implementation alongside the Rust one. `fuzzy.implementation` defaults to `require('blink.cmp.fuzzy.lua')`, and `set_implementation('lua'|'rust')` switches between them. The Rust module (`fuzzy/rust/init.lua`) is just `native.load(name, commit)`. Both expose the same interface (`set_provider_items`, `get_words`, `fuzzy_matched_indices`, `init_db`, `access`). — [blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)
- blink.cmp reduces Lua↔Rust crossing costs by caching haystacks per provider: "set the provider items once since Lua <-> Rust takes the majority of the time". For frecency DB writes (~10 ms) it uses `vim.uv.new_work`: a thread-pool worker re-`loadlib`s the same library path and receives items serialized with `string.buffer` or `vim.mpack`. — [blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)
- **frizbee** is a plain Rust library ("Fast typo-resistant fuzzy matching via SIMD smith waterman"), now at version 0.13.0. It has a workspace of bindings (`frizbee-c`, `frizbee-py`, `frizbee-wasm`) and no mlua dependency of its own. The Neovim plugins (blink.cmp, and fff as `neo_frizbee`) wrap it with mlua. — [frizbee Cargo.toml](https://github.com/saghen/frizbee/blob/main/Cargo.toml); [fff Cargo.toml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/Cargo.toml)
- **blink.lib** (new in the blink.cmp V2 timeframe) pulls the native-library plumbing into a shared plugin. `blink.lib.native` provides "Build and download APIs for native libraries". `blink.lib.native.managed` is "an opinionated setup used in `blink.*` plugins", and blink.pairs is the example (library `blink_pairs_parser`). — [blink.lib README](https://github.com/saghen/blink.lib/blob/main/README.md)
- **fff.nvim** (repo now `dmtrKovalenko/fff`, package renamed from `fff.nvim` to `fff`) is a Cargo workspace: `fff-core`, `fff-nvim`, `fff-c`, `fff-mcp`, `fff-python`, `fff-query-parser`, `fff-grep`. It uses `mlua = { version = "0.11.1", features = ["module", "luajit"] }`. Only `fff-nvim` is the Neovim cdylib, and the core is reused by an MCP server, a C API and Python bindings. — [fff Cargo.toml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/Cargo.toml); [fff README](https://github.com/dmtrKovalenko/fff.nvim/blob/main/README.md)
- fff's loader deliberately avoids `require`. The comment reads: "Instead of using require (which can find the wrong lib due to cpath pollution), load the library directly from the first valid path we find". It searches the download dir, `../../../target/release/lib?.{ext}`, and `$CARGO_TARGET_DIR/release`. On Windows it converts `/` to `\` "so that Windows APIs (LoadLibraryEx) can find the file". — [fff lua/fff/rust/init.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/rust/init.lua)
- **avante.nvim** is a Cargo workspace (`members = ["crates/*"]`, edition 2024, `rust-version = "1.94"`) with four separate cdylibs: `avante-tokenizers`, `avante-templates`, `avante-repo-map`, and `avante-html2md`. It uses `mlua = { version = "0.12.1", features = ["module", "serialize"] }` at workspace level. Each crate exposes features `lua51`/`lua52`/`lua53`/`lua54`/`luajit`, with `default = ["luajit"]`. — [avante Cargo.toml](https://github.com/yetone/avante.nvim/blob/main/Cargo.toml); [avante-tokenizers Cargo.toml](https://github.com/yetone/avante.nvim/blob/main/crates/avante-tokenizers/Cargo.toml)
- avante's Makefile copies `target/release/libavante_<x>.{so|dylib}` to `lua/avante_<x>.so`. Its comment: on macOS ".so … looks interchangeable with 'dylib', but nvim will find .so automatically in rtp". Lua then loads the module with `pcall(require, "avante_tokenizers")` and returns nil if it's missing, so the feature degrades gracefully. — [avante Makefile](https://github.com/yetone/avante.nvim/blob/main/Makefile); [avante tokenizers.lua](https://github.com/yetone/avante.nvim/blob/main/lua/avante/tokenizers.lua)
- **toml-edit.lua** (lumen-oss; used by rocks.nvim) is a single cdylib (`[lib] name = "toml_edit"`) with features `lua55`/`lua54`/`lua53`/`lua52`/`luajit`/`lua51` that map to mlua features, and uses `mlua = { version = "0.11", features = ["module", "serialize"] }`. — [toml-edit.lua Cargo.toml](https://github.com/lumen-oss/toml-edit.lua/blob/master/Cargo.toml)
- The mlua README lists these Rust modules as published to luarocks: `decasify`, `lua-ryaml`, `tiktoken_core`, `toml-edit`, and `typst-lua`. — [mlua README](https://github.com/mlua-rs/mlua/blob/main/README.md)
- mlua versions: v0.12.0 was released Jul 05, 2026, v0.12.1 on Aug 29, 2026, and v0.12.2 on Oct 03, 2026. The current README examples use `mlua = { version = "0.12", ... }`. — [mlua CHANGELOG](https://github.com/mlua-rs/mlua/blob/main/CHANGELOG.md)
- In module mode, mlua "uses an external Lua runtime which could lead to potential unsafety due to the unpredictability of the Lua environment and usage of libraries such as `debug`". Entry points use `#[mlua::lua_module]`, which generates `luaopen_<name>`. — [mlua README](https://github.com/mlua-rs/mlua/blob/main/README.md)

### Inferences
- As of October 2026 the ecosystem is split between mlua 0.11 (blink.cmp, fff, toml-edit) and 0.12 (avante). A new project should start on 0.12. 0.12 refactored root re-exports, so upgrading needs some import churn.
- The emerging best practice is "Rust core crate + thin mlua cdylib crate + pure-Lua orchestration". fff's workspace shows the payoff: the same core ships to several hosts.
- Loading by absolute path with `package.loadlib` is more robust than relying on `package.cpath`. Both blink and fff moved to it.

### Gaps
- I didn't inventory every mlua plugin. sg.nvim, codesnap.nvim and others may have used mlua at some point, but I didn't verify their current state. nvim-oxi is a different binding approach and is out of scope.

## Q2: How do they distribute binaries?

### Takeaway
The dominant pattern is prebuilt per-target-triple release assets on GitHub Releases, downloaded at install time by a plugin-manager `build` hook. Building with `cargo build --release` is offered as a fallback or opt-in. Nix flakes are a common third channel. LuaRocks via `luarocks-build-rust-mlua` (the rocks.nvim path) always compiles from source on the user's machine.

### Cited Findings
- **blink.cmp V1:**
  - It downloaded `<triple><ext>` plus `<triple><ext>.sha256` from `releases/download/<tag>/`.
  - The pinned git tag decided the version, and the user had to set `version = '1.*'`.
  - Config options were `prebuilt_binaries.download`, `force_version`, and `ignore_version_mismatch`.
  - A `version` file next to the library recorded the tag, or the 40-character SHA when built locally.
  — [blink.cmp v1.6.0 download/init.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/init.lua); [files.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/files.lua)
- **blink.cmp V2 (current main, under active development; README says "Consider staying on stable by using `branch = 'v1'` or `version = "1.*"`"):**
  - It removed `prebuilt_binaries`.
  - Building moved to the package manager: `'cargo build --release'` became `require('blink.cmp').build():pwait()`, and the library path moved from `target/release/` to `lib/`.
  - Manual download is now `require('blink.cmp').download({ force = true, tags = '*' }):pwait()`.
  - It now requires `saghen/blink.lib`.
  — [blink.cmp UPGRADE.md](https://github.com/Saghen/blink.cmp/blob/main/UPGRADE.md); [README](https://github.com/Saghen/blink.cmp/blob/main/README.md)
- **blink.lib managed flow:** `download()` asserts a git tag exists ("Missing git tag, have you pinned the version? Set `version = "*"` for lazy.nvim or `version = vim.version.range("*")` for vim.pack"). It builds the URL from `git_tag` + `platform.triple` + `lib_extension` and downloads with `vim.net.request`. The library is stored as `$repo/lib/lib<name><ext>.<7-char-commit>`, then resolved through `nvim_get_runtime_file('lib/lib<name><ext>.<hash>')`. blink.pairs tells users to add `build = function() require('blink.pairs').build():pwait(60000) end` or `.download():pwait(60000)`. — [blink.lib native/managed.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/managed.lua); [native/init.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/init.lua); [blink.lib README](https://github.com/saghen/blink.lib/blob/main/README.md)
- **fff:**
  - The lazy.nvim spec is `build = function() require("fff.download").download_or_build_binary() end`, commented "downloads a prebuilt binary or falls back to cargo build". The Nix alternative is `build = "nix run .#release"`.
  - The download URL is `https://github.com/dmtrKovalenko/fff/releases/download/<version>/<triple>.<ext>`.
  - The version comes from the CI-created tag on HEAD. Without a tag, fff computes a "nightly" version, so it publishes nightly prereleases as well as tagged releases.
  — [fff README](https://github.com/dmtrKovalenko/fff.nvim/blob/main/README.md); [fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)
- **avante:**
  - The lazy.nvim spec is `build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make"` together with `version = false, -- Never set this value to "*"! Never!`.
  - `make BUILD_FROM_SOURCE=true` builds from source. Otherwise `build.sh` uses `git ls-remote --tags` to find the latest `v*` tag and curls `avante_lib-<platform>-<arch>-<luajit|lua51>.tar.gz` piped into `tar` into `lua/`. It records the tag in `lua/.tag` to skip re-downloads, and the `:AvanteBuild source=true` command builds from source.
  - avante also documents vim.pack (a `PackChanged` autocmd that runs `make`) and rocks.nvim (`:Rocks install avante.nvim`).
  — [avante README](https://github.com/yetone/avante.nvim/blob/main/README.md); [build.sh](https://github.com/yetone/avante.nvim/blob/main/build.sh)
- **luarocks-build-rust-mlua:**
  - It needs `cargo` installed ("This rock is written in Rust: make sure you have a Rust development environment installed").
  - It picks the mlua feature from `cfg.lua_version`: 5.5 → `lua55` … 5.1 → `luajit` if LuaJIT is detected, else `lua51`.
  - It runs `cargo build --release --target-dir=… --features …`.
  - It copies `lib<name>.<ext>` (or `<name>.dll` on Windows) to the rock's lib dir as `<mod>.<lib_extension>`.
  - Rockspec options are `modules`, `target_path`, `default_features`, `cargo_extra_args`, `include`, and `features`.
  — [rust-mlua.lua](https://github.com/mlua-rs/luarocks-build-rust-mlua/blob/main/src/luarocks/build/rust-mlua.lua); [README](https://github.com/mlua-rs/luarocks-build-rust-mlua/blob/main/README.md)
- **rocks.nvim ecosystem:** a `rocks-binaries` server provides prebuilt, autogenerated binaries (for example tree-sitter parsers, "so users often don't need gcc"). It is built using NixOS cross-compilation, and an open issue asks for arm64 builds. The rocks.nvim README warns of a major rewrite and suggests waiting for v3.0.0. (This is from search-result summaries of the GitHub discussion and repo pages, which I didn't fetch directly.) — [rocks.nvim discussion #229](https://github.com/lumen-oss/rocks.nvim/discussions/229); [neovimcraft rocks.nvim page](https://erock-neovimcraft-1782466063.pgs.sh/plugin/lumen-oss/rocks.nvim/)
- **Nix:**
  - blink.cmp's `flake.nix` builds the Rust library with `rustPlatform.buildRustPackage` (`cargoLock.lockFile = ./Cargo.lock`) and symlinks it into `lib/` in `preInstall` of `vimUtils.buildVimPlugin`.
  - It exposes an overlay that adds `vimPlugins.blink-cmp`.
  - It sets `nvimSkipModules = ["blink.cmp.fuzzy.rust.init"]` because nixpkgs' `nvimRequireCheckHook` adds the plugin to rtp multiple times, so blink.lib finds duplicate libraries.
  - nixpkgs also packages rocks.nvim for luajit/lua51/lua55.
  — [blink.cmp flake.nix](https://github.com/Saghen/blink.cmp/blob/main/flake.nix); [MyNixOS rocks-nvim](https://mynixos.com/nixpkgs/package/vimPlugins.rocks-nvim)

### Inferences
- Over 2025–2026 the trend has been away from plugin-internal download logic tied to config options (blink V1 `prebuilt_binaries`) and toward explicit `build()`/`download()` functions that users call from their plugin-manager hook. Those functions return awaitable tasks (`:pwait()`) so lazy.nvim/vim.pack hooks block until the work finishes. vim.pack, Neovim's built-in package manager, is now a first-class target next to lazy.nvim.
- Tying the binary version to a git tag forces users to pin to releases. avante does the opposite: it always fetches the *latest* tag and tells users never to pin. Both conventions confuse users who get them wrong.
- Shipping separate artifacts for `lua51` and `luajit` (avante) only matters for non-Neovim hosts. Neovim users effectively always need `luajit`.

### Gaps
- I didn't read avante's `Build.ps1` or the full `lua/avante` loader path. I also didn't verify which rocks on luarocks.org ship prebuilt binary rocks versus source rocks for Rust plugins.

## Q3: ABI/version mismatches, missing binaries, fallbacks, checksums, target triples

### Takeaway
Plugins detect the platform from `jit.os`/`jit.arch` and detect libc by sniffing the ELF interpreter for "musl". They map the result to Rust target triples and fetch `<triple>.<ext>`. Version safety comes from tying the binary to the git tag or commit: blink V1 used a version file, blink V2 puts the commit hash in the filename. Pure-Lua fallback exists in blink.cmp, and avante silently degrades. Checksum verification existed in blink V1 (sha256sum/certutil) but is absent from the current blink.lib downloader. fff and blink V2 instead validate by trial `package.loadlib`.

### Cited Findings
- **blink.lib platform detection:**
  - `os` comes from `jit.os` (BSD refined via `vim.uv.os_uname().sysname`) and `arch` from `jit.arch`.
  - libc detection reads the first 4 KB of `/proc/self/exe`, which "always contains the PT_INTERP string", and returns `musl` if it matches, else `gnu`.
  - The triple table covers mac x64/arm64 (`*-apple-darwin`), windows x64/arm64 (`*-pc-windows-msvc`), linux x64/arm64/loongarch64 for gnu/musl, android (`aarch64-linux-android`, `x86_64-linux-android`), freebsd, and openbsd.
  - Unknown platforms produce `Unknown platform (os: …, arch: …)`.
  — [blink.lib native/platform.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/platform.lua)
- **blink V2 version safety:** `native.library_path` appends `.<first 7 chars of commit>` to the filename, and `resolve()` looks for the hashed name first, then falls back to an unhashed `lib<name><ext>`. If several matches exist it errors with "Found multiple instances of the same library… the latest update moved the binary from `site/lib/*` to `$repo/lib/*`. Please remove the former". `build({dev=true})` writes the unhashed name for local development. — [blink.lib native/init.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/init.lua); [managed.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/managed.lua)
- **blink V1 mismatch logic:**
  - If no version file exists but `require('blink.cmp.fuzzy.rust')` works, it assumed the user placed the library manually.
  - It warned "outdated version" unless `ignore_version_mismatch` was set.
  - It errored when not on a git tag and told users to set `version = '1.*'` or `force_version`.
  - If the tag matched, it re-verified the checksum and re-downloaded on failure.
  - It wrote version `v0.0.0` before downloading "to avoid a failure causing the pre-built binary being marked as locally built".
  — [blink.cmp v1.6.0 download/init.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/init.lua)
- **blink V1 fallback:** `fuzzy.implementation` accepted `'lua'`, `'prefer_rust'` (silent fallback to Lua), `'prefer_rust_with_warning'` (fallback plus a warning telling users to set `implementation = "lua"`), and `'rust'` (hard error "rust implementation forced"). — [blink.cmp v1.6.0 download/init.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/init.lua)
- **blink V1 checksums:** it downloaded `<triple><ext>.sha256`. It computed the local hash with `sha256sum` on Unix and `certutil -hashfile <path> SHA256` on Windows, and compared it against the downloaded file ("Checksum of pre-built binary does not match"). — [blink.cmp v1.6.0 files.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/files.lua)
- **blink CI checksums:** the release workflow still generates `sha256sum "$file" > "${file}.sha256"` for every asset. — [blink.cmp release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml)
- The current `blink.lib.native.download` (via `vim.net.request`) and `managed:download` contain no checksum check. They only assert that the library resolves afterwards ("Failed to load downloaded library"). — [blink.lib native/init.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/init.lua); [managed.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/managed.lua)
- **blink V2 missing binary:** blink.pairs' `setup()` shows an error that tells the user to add the `build` or `download` hook. — [blink.lib README](https://github.com/saghen/blink.lib/blob/main/README.md)
- **fff validation:** it downloads to `<path>.tmp` and validates with `package.loadlib(tmp_path, 'luaopen_fff_nvim')` before renaming. The reason given: "If we wrote directly to binary_path and the current process already has the old library loaded, package.loadlib() on the same path returns the *cached* handle — meaning a truncated download would pass validation silently." In the code I grepped I found no checksum verification in fff's downloader. — [fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)
- **fff missing binary:** the loader errors with the searched paths and tells the user to run `:lua require("fff.download").download_or_build_binary()` or `cargo build --release` "(and rerun neovim after)". — [fff rust/init.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/rust/init.lua)
- **avante:** it does no checksum verification (`curl -L … | tar -zxv`). Its only arch handling is `x86_64` and `aarch64`/`arm64`, with "Unsupported architecture" otherwise. It doesn't distinguish musl from glibc. — [avante build.sh](https://github.com/yetone/avante.nvim/blob/main/build.sh)
- **glibc baselines (they conflict):**
  - blink.cmp's `Cross.toml` uses `ghcr.io/cross-rs/*:main-centos` images, commented "centos images use glibc 2.17", while its release workflow comment says "Glibc 2.21". — [blink.cmp Cross.toml](https://github.com/Saghen/blink.cmp/blob/main/Cross.toml); [release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml)
  - avante builds x86_64 Linux in `quay.io/pypa/manylinux2014_x86_64 # for glibc 2.17`. — [avante release.yaml](https://github.com/yetone/avante.nvim/blob/main/.github/workflows/release.yaml)
  - fff targets glibc 2.31 via `cargo zigbuild --target x86_64-unknown-linux-gnu.2.31`. Its comment claims "Rust 1.91+ requires glibc >= 2.31 for std::sys::random::getrandom, copy_file_range, and statx; earlier targets (2.17) no longer link". This contradicts blink and avante, which still target 2.17. I didn't check fff's claim against Rust's official platform-support docs. — [fff release.yaml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/.github/workflows/release.yaml)
- **musl:** blink builds musl targets with `rustflags = ["-C", "target-feature=-crt-static"]`, which keeps the cdylib dynamically linked against musl so it can be `dlopen`ed by a musl Neovim. fff's workflow comment says "Musl (statically linked)". — [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml); [fff release.yaml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/.github/workflows/release.yaml)
- **macOS:** module builds need `-C link-arg=-undefined -C link-arg=dynamic_lookup` (blink sets this in `.cargo/config.toml` for both Apple triples). blink builds with `MACOSX_DEPLOYMENT_TARGET="13"` (Ventura). — [mlua README](https://github.com/mlua-rs/mlua/blob/main/README.md); [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml); [release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml)
- **Windows:** "the target module will be linked with the `lua5x.dll` library … Your main application should provide this library". With the `luajit` feature this is the `lua51.dll` that ships with nvim.exe. — [mlua README](https://github.com/mlua-rs/mlua/blob/main/README.md)
- **Windows user report:** a Reddit thread (Dec 2024) describes blink.cmp on Windows 10 failing with "error loading module 'blink_cmp_fuzzy' … libblink_cmp_fuzzy.dll … not a valid Win32 application". The thread never confirmed a fix. — [r/neovim thread (mirror)](https://axebps-redlib.hf.space/r/neovim/s/A7934xKTnT)
- **Android:** blink and fff both ship `aarch64-linux-android` (Termux). blink links it with `-rdynamic` and `default-linker-libraries`, and fff uses the NDK `aarch64-linux-android24-clang` linker. — [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml); [fff release.yaml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/.github/workflows/release.yaml)

### Inferences
- An "ABI mismatch" for mlua modules in Neovim is really a version mismatch between the Lua glue and the Rust exports, because Neovim always embeds LuaJIT (the Lua 5.1 ABI). Encoding the commit in the filename (blink V2) is the cleanest guard, because a stale library simply isn't found.
- The CI still publishes `.sha256` files, but the clients that used to check them no longer do. Teams with supply-chain concerns should add verification themselves.
- The `-crt-static` flag for musl targets is a subtle but important detail. A statically linked musl cdylib generally can't be `dlopen`ed reliably.

### Gaps
- I didn't confirm whether blink V2 relies on GitHub's TLS alone, or whether anyone uses signed artifacts or attestations (`actions/attest-build-provenance`) for Neovim plugin binaries.
- I found no authoritative statement of the minimum glibc that current stable Rust supports, so the 2.17 vs 2.31 conflict is unresolved.

## Q4: CI setups (cross-compilation matrices, cargo-zigbuild, cross)

### Takeaway
GitHub Actions matrix builds on tag push are universal. They use native macOS and Windows runners (including `aarch64-pc-windows-msvc`), and Linux targets are cross-compiled with either `cross` (blink.cmp) or `cargo-zigbuild` (fff; it pins the glibc version in the target string). avante instead uses a native ARM runner (`ubuntu-24.04-arm`) and a manylinux container. Assets are named `<triple>.<ext>` (blink, fff) or `avante_lib-<os>-<arch>-<lua>.tar.gz`, and are uploaded with `softprops/action-gh-release` or `gh release upload --clobber`.

### Cited Findings
- **blink.cmp** `release.yaml` triggers on `tags: v*` and has 13 matrix targets:
  - Linux gnu and musl for x86_64, aarch64, and loongarch64
  - `aarch64-linux-android`
  - FreeBSD x86_64 and aarch64 (aarch64 needs nightly `-Z build-std`)
  - macOS x86_64 and aarch64
  - Windows x86_64 and aarch64 msvc

  Linux uses `cargo install cross --git https://github.com/cross-rs/cross` then `cross build --release --target …`. A separate OpenBSD job builds inside a VM via `cross-platform-actions/action` (OpenBSD 7.9). Artifacts are renamed to `<target>.so|.dylib|.dll`, checksummed, and published with `softprops/action-gh-release`. Actions are pinned by commit SHA. — [blink.cmp release.yaml](https://github.com/Saghen/blink.cmp/blob/main/.github/workflows/release.yaml)
- blink's release profile uses `lto = true`, `codegen-units = 1`. — [blink.cmp .cargo/config.toml](https://github.com/Saghen/blink.cmp/blob/main/.cargo/config.toml)
- **fff:**
  - It installs `cargo-zigbuild` and runs `cargo zigbuild --profile ci --target <triple>[.2.31] -p fff-nvim --no-default-features --features zlob`.
  - It defines a `ci` profile that inherits release but uses `lto = "thin"`, with the comment "we use lto=fat locally for better SIMD for the march=native but on CI when we cross compiling we should not exclude any cpu flags checking".
  - It caches the per-target build dir and the zigbuild binary ("See issue on slow release CI").
  - It builds Android with the NDK directly and builds macOS/Windows natively.
  - The release workflow also bumps a Homebrew formula for `fff-mcp`.
  — [fff release.yaml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/.github/workflows/release.yaml); [fff Cargo.toml](https://github.com/dmtrKovalenko/fff.nvim/blob/main/Cargo.toml); [fff README](https://github.com/dmtrKovalenko/fff.nvim/blob/main/README.md)
- **avante** `release.yaml`:
  - The matrix is `feature: [lua51, luajit]` × {`ubuntu-24.04-arm` aarch64-linux-gnu, `ubuntu-latest` x86_64-linux-gnu in a `manylinux2014_x86_64` container, macOS x86_64 and aarch64, Windows x86_64 and aarch64 msvc}.
  - It uploads `avante_lib-<os>-<arch>-<feature>.tar.gz` with `--clobber`.
  - Its Makefile has an `upgrade-actions` target that uses `ratchet` to pin actions.
  — [avante release.yaml](https://github.com/yetone/avante.nvim/blob/main/.github/workflows/release.yaml); [avante Makefile](https://github.com/yetone/avante.nvim/blob/main/Makefile)
- The mlua README says mlua is "tested on Windows/macOS/Linux including module mode in GitHub Actions on `x86_64` platforms and cross-compilation to `aarch64`". — [mlua README](https://github.com/mlua-rs/mlua/blob/main/README.md)
- The rocks-binaries server uses NixOS cross-compilation (per search-result summary). — [rocks.nvim discussion #229](https://github.com/lumen-oss/rocks.nvim/discussions/229)

### Inferences
- Module mode needs no Lua headers or libraries on Linux and macOS ("Module builds don't require Lua binaries or headers"), so cross-compiling an mlua cdylib is easy. The C toolchain and glibc baseline are the hard parts, and cargo-zigbuild's `.2.xx` suffix is the lightest way to pin glibc without containers.
- A reasonable minimal matrix for a new plugin is: x86_64/aarch64 linux-gnu, x86_64/aarch64 linux-musl, aarch64/x86_64 apple-darwin, and x86_64-pc-windows-msvc. aarch64 Windows, Android, and the BSDs are long-tail targets that blink adds.

### Gaps
- I didn't see per-PR CI (lint/test) workflows in detail. Only release workflows were inspected.

## Q5: Hot-reload/dev workflow problems (can't unload .so, restarts, Windows DLL locking)

### Takeaway
Once loaded, a native module stays mapped for the life of the Neovim process. A second `package.loadlib` on the same path returns the cached handle, and Windows locks the DLL file. Real plugins work around this by never overwriting the loaded file in place. fff downloads to `.tmp` and promotes it on the next start. blink renames the old file away, unlinks it, and uses commit-hashed filenames. Both tell users to restart Neovim after building.

### Cited Findings
- fff: `package.loadlib()` on a path that's already loaded "returns the *cached* handle", so it validates downloads at a separate `.tmp` path. — [fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)
- fff on Windows: "On Windows the rename over a loaded DLL fails, so a verified binary may be left at binary_path .. '.tmp'. Promote it now that the old session is gone." On the next startup `binary_exists()` re-validates the `.tmp` with `loadlib` (in case "the process was killed between the loadlib check and the rename attempt") and then renames it into place. — [fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua)
- fff warns "Do not open fff until you see a success notification". Its download-or-build chain is waited on synchronously in the build hook because, if "Neovim exits before the final rename(tmp → libfff_nvim.{dylib,so,dll})", the install is incomplete. A timeout raises `download_or_build_binary timed out`. The loader error message tells the user to "rerun neovim after" building. — [fff download.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/download.lua); [fff rust/init.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/rust/init.lua)
- blink.lib download: "if file exists, rename it and fs_unlink it to mark for garbage collection". The old file becomes `path .. '.old.' .. random_hash`, which avoids writing into a mapped file. — [blink.lib native/init.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/init.lua)
- blink V1 likewise downloaded to `<lib>.tmp` and renamed it, with a code comment pointing to the reason ("We instead write to a temporary file and rename it"). — [blink.cmp v1.6.0 download/init.lua](https://github.com/Saghen/blink.cmp/blob/v1.6.0/lua/blink/cmp/fuzzy/download/init.lua)
- blink V2 dev workflow: `build({ dev = true })` writes the un-hashed `lib<name><ext>`. `build`/`download` re-read the git commit because "the commit may have changed since this module was loaded". The library goes in `$repo/lib/` and is found through `runtimepath`, and the repo root is appended to rtp before resolving. — [blink.lib managed.lua](https://github.com/saghen/blink.lib/blob/main/lua/blink/lib/native/managed.lua)
- fff's loader also checks `$CARGO_TARGET_DIR/release` and `target/release`, so a plain `cargo build --release` in a dev checkout is picked up on the next Neovim start without a copy step. blink.cmp's `build()` likewise honors `CARGO_TARGET_DIR`. — [fff rust/init.lua](https://github.com/dmtrKovalenko/fff.nvim/blob/main/lua/fff/rust/init.lua); [blink.cmp init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/init.lua)
- blink.cmp shows another consequence of process-global native state: its threaded frecency writer loads the library again inside a `vim.uv.new_work` thread (a separate Lua state), and it registers `destroy_db` on `VimLeavePre` to clean up native resources. — [blink.cmp fuzzy/init.lua](https://github.com/Saghen/blink.cmp/blob/main/lua/blink/cmp/fuzzy/init.lua)

### Inferences
- Practical dev loop:
  1. Run `cargo build`.
  2. Restart Neovim, for example with `:restart`, or use a headless `nvim -l` test harness.
  3. Load from `target/` through an explicit path.

  Writing a new file under a new name (a hash or timestamp suffix) and loading that would technically allow a second copy to load in-process. But module-level statics, tables already captured in Lua, and threads from the old copy would remain, so plugins don't attempt real hot reload.
- On Windows, never overwrite a loaded DLL in place. Rename the old one away first (Windows allows renaming a loaded DLL), or stage the new one and promote it on next start. Both approaches appear in production code above.

### Gaps
- I found no primary-source documentation (mlua, LuaJIT, or Neovim docs) or issue thread that explicitly states "native modules cannot be unloaded". The claim rests on the plugin code comments above plus general knowledge of `dlopen`/`LoadLibrary` and Lua's `package.loadlib` caching. Web searches for blink.cmp Windows DLL-lock issues didn't turn up a specific thread, because the GitHub API was rate-limited and search results were sparse.
