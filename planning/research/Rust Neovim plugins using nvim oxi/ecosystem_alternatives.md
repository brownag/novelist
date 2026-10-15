# nvim-oxi Ecosystem, Project Health, and Alternatives for Rust Neovim Plugins (as of 2026-10-11)

Method note: Metrics come from the GitHub REST API, crates.io API, and raw `Cargo.toml` files fetched on 2026-10-11 unless stated otherwise. Reddit's API was blocked and the Neovim Discourse domain (neovim.discourse.group) did not resolve, so community sentiment is thin (see Gaps).

## Which notable plugins use nvim-oxi, what for, and what patterns they share

### Takeaway
Very few high-profile plugins use nvim-oxi. The largest one is **nomad** (real-time collaborative editing, by noib3, the nvim-oxi author). The biggest Rust-backed Neovim plugins (blink.cmp, blink.pairs, avante.nvim, fff.nvim) all use **plain mlua in module mode**, not nvim-oxi. The common pattern across both camps is a Lua frontend with a Rust core loaded as a `cdylib`, plus prebuilt binaries downloaded at install time.

### Cited Findings
**nvim-oxi users (verified via Cargo.toml)**
- **nomad/nomad**: 692 stars, last push 2026-10-11, tagline "Make coding delightful". It "brings real-time collaborative editing to Neovim" using custom CRDTs. — [GitHub nomad/nomad](https://github.com/nomad/nomad)
- nomad depends on nvim-oxi via **git master** (`nvim-oxi = { git = "https://github.com/noib3/nvim-oxi" }`), not a crates.io release. It is a large Rust workspace (async-io, CRDT/collab-server crates, git2, rustls, and more) with a `lua/` directory. — [nomad Cargo.toml](https://raw.githubusercontent.com/nomad/nomad/main/Cargo.toml)
- nomad's install docs say: "Being written in Rust, Nomad requires a build step before it can be loaded by Neovim… we currently only support lazy.nvim." Users pick a builder: `download_prebuilt()`, `cargo()` (which "needs `cargo` from a nightly version of the Rust toolchain"), or `nix()`. — [nomad installation.md](https://raw.githubusercontent.com/nomad/nomad/main/docs/installation.md)
- nomad's GitHub release assets are built **per Neovim version and per platform**, for Linux and macOS only (x86_64 and aarch64). For example, `nomad-2025.11.2-for-neovim-0.11-linux-x86_64.tar.gz` and `...-for-neovim-0.12-nightly-macos-aarch64.tar.gz`. The listing has no Windows assets. — [nomad releases (GitHub API)](https://api.github.com/repos/nomad/nomad/releases)
- Saghen's older **blink.nvim** (252 stars; it has a `blink_delimiters` crate) uses `nvim-oxi = { version = "0.5.1", features = ["neovim-0-10"] }`. — [blink.nvim Cargo.toml](https://raw.githubusercontent.com/saghen/blink.nvim/main/Cargo.toml)
- **nvim-spectre** (2,410 stars, last push 2025-05-19) ships an optional `spectre_oxi` replace engine pinned to `nvim-oxi = { version = "0.3.0", features=["neovim-0-9"] }`, which is several versions stale. — [spectre_oxi Cargo.toml](https://raw.githubusercontent.com/nvim-pack/nvim-spectre/master/spectre_oxi/Cargo.toml)
- **MarcusGrass/nvim_winpick** (55 stars) uses nvim-oxi 0.6.0 with `neovim-0-10` and `neovim-0-11`. — [nvim_winpick Cargo.toml](https://raw.githubusercontent.com/MarcusGrass/nvim_winpick/main/Cargo.toml)
- GitHub's dependents graph shows about **165 repositories and 5 packages**. Apart from blink.pairs and blink.nvim, the top listed dependents are small: nvim_winpick (55), age.nvim (21), fcitx5-ui-rs.nvim (9), vim-reviewer (8), then many personal configs and templates with 0–3 stars. — [GitHub dependents](https://github.com/noib3/nvim-oxi/network/dependents)
- crates.io lists only **5 reverse dependencies**: just_nvim (^0.5.1), umasi (^0.4), tane (^0.6), shikake (^0.6), narabi (^0.6). — [crates.io reverse deps API](https://crates.io/api/v1/crates/nvim-oxi/reverse_dependencies)

**Plugins that use mlua instead of nvim-oxi (checked because they are often assumed to use nvim-oxi)**
- **blink.cmp** (6,624 stars): its fuzzy crate `blink-cmp-fuzzy` uses `mlua = { version = "0.11.3", features = ["module", "luajit"] }` and **not** nvim-oxi. — [blink.cmp Cargo.toml](https://raw.githubusercontent.com/Saghen/blink.cmp/main/Cargo.toml)
- **blink.pairs** (299 stars) uses `mlua 0.11.6` (luajit, module). This is notable because GitHub's dependents graph lists it as an nvim-oxi dependent, which suggests a past dependency or a transitive or stale graph entry. — [blink.pairs Cargo.toml](https://raw.githubusercontent.com/saghen/blink.pairs/main/Cargo.toml); [GitHub dependents](https://github.com/noib3/nvim-oxi/network/dependents)
- **avante.nvim**, now `avante-corp/avante.nvim` (18,183 stars), has a workspace of `crates/*` that uses `mlua = { version = "0.12.1", features = ["module", "serialize"] }`. — [avante Cargo.toml](https://raw.githubusercontent.com/yetone/avante.nvim/main/Cargo.toml)
- **fff.nvim**, now `dmtrKovalenko/fff` (11,076 stars), uses `mlua 0.11.1` (module, luajit). — [fff Cargo.toml](https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/main/Cargo.toml)
- blink.cmp's Rust matcher (frizbee, SIMD) is optional. `fuzzy.implementation` can be set to `prefer_rust_with_warning`, `prefer_rust`, `rust`, or `lua`, and the plugin falls back to Lua when the download fails or the platform is unsupported. Prebuilt binaries cover Linux (glibc and musl, x86_64 and aarch64), Android/Termux, macOS, Windows (x86_64 and aarch64), and FreeBSD/OpenBSD. The docs claim "~6x the performance of fzf". — [blink.cmp fuzzy docs](https://cmp.saghen.dev/configuration/fuzzy)

### Inferences
- **Pattern split:**
  - nvim-oxi users tend toward *Rust-heavy* plugins that call the Neovim API directly from Rust: nomad drives buffers, extmarks, and autocmds from Rust, and window pickers and delimiter highlighters do the same.
  - mlua users tend toward a *Rust compute kernel plus Lua frontend*: fuzzy matching, file search, repo-map and templating in avante. Rust only crunches data, and Lua owns all editor interaction.
  - The second pattern dominates by stars by orders of magnitude.
- Saghen moved from nvim-oxi (blink.nvim) to mlua (blink.cmp, blink.pairs). This is circumstantial evidence that a prominent Rust plugin author preferred mlua for distributable plugins. I did not find a stated reason (see Gaps).
- Only the mlua-based plugins ship one binary per platform that works across Neovim versions. nomad ships binaries per Neovim version, which follows from nvim-oxi binding Neovim's C structs and functions directly (see the health section).

### Gaps
- I could not find a public statement from Saghen on why blink.cmp and blink.pairs use mlua rather than nvim-oxi.
- I did not enumerate GitHub dependents beyond the first page (30 of about 165). There may be other mid-size users.
- I did not verify whether sg.nvim (Sourcegraph) or sniprun use nvim-oxi. The sg.nvim root Cargo.toml showed neither `mlua` nor `nvim-oxi` at the workspace root. sniprun is commonly described as an RPC-based Rust binary, but I did not confirm this.

## Project health of nvim-oxi

### Takeaway
nvim-oxi is a mature-looking project with essentially **a single maintainer** (noib3 has 752 commits; the next contributor has 25). It has about 1.1k stars. The last crates.io release (0.6.0) was **in May 2025**, nearly 17 months ago, so Neovim 0.12 support exists only on git master. Master's last commit was **2026-05-17**, and Neovim 0.12.x patch releases have broken struct layouts that remain unfixed in open issues and PRs. Health is fair to declining.

### Cited Findings
- **GitHub, as of 2026-10-11:** 1,139 stars, 64 forks, 43 open issues plus PRs, created 2022-05-12, MIT license, last push 2026-05-17. — [GitHub API noib3/nvim-oxi](https://api.github.com/repos/noib3/nvim-oxi)
- **Contributors by commits:** noib3 752, n-shift 25, zjp-CN 12, maan2003 10, myypo 8, ModProg 7, theofabilous 6, c-c-k 4. — [GitHub contributors API](https://api.github.com/repos/noib3/nvim-oxi/contributors)
- **crates.io release history:** 0.1.2 (2022-07-16), 0.2.0 (2022-10-15), 0.3.0 (2023-04-21), 0.4.0 (2023-12-10), 0.4.2 (2024-01-29), 0.5.0 (2024-05-28), 0.5.1 (2024-06-23), **0.6.0 (2025-05-23, latest)**. Cadence has been roughly 1–2 releases per year, and nothing has shipped since May 2025. Totals are 58,465 all-time downloads and 5,323 recent (90-day) downloads. — [crates.io API](https://crates.io/api/v1/crates/nvim-oxi)
- **Recent master commits:**
  - 2026-04-04: CI tests against 0.11.7.
  - 2026-04-06: "api: add a `neovim-0-12` feature" (#295), "api: drop support for `neovim-0-10`" (#302), and "fix `WindowOpts`'s layout on 0.12 and Nightly" (#301).
  - 2026-05-17: noib3 bumps the MSRV to 1.91.0 and stops gitignoring Cargo.lock.
  - No commits since then. — [GitHub commits API](https://api.github.com/repos/noib3/nvim-oxi/commits)
- **Neovim release timeline:** 0.11.7 on 28 Mar, 0.12.0 on 29 Mar, 0.12.1 on 6 Apr, 0.12.2 on 22 Apr, 0.12.3 on 10 Jun, 0.12.4 on 5 Jul, 0.12.5 on 23 Aug, and 0.12.6 on 9 Oct (all 2026). Nightly is now 0.13.0-dev. — [Neovim releases](https://github.com/neovim/neovim/releases)
  - **Support lag:** master gained a `neovim-0-12` feature about 8 days after 0.12.0 shipped, but no crates.io release includes it. Users must depend on git, which nomad does.
- **Feature flags on master:** `neovim-0-11`, `neovim-0-12`, `neovim-nightly`, `libuv`, `mlua`, `test`, `test-terminator`. — [nvim-oxi Cargo.toml](https://raw.githubusercontent.com/noib3/nvim-oxi/main/Cargo.toml)
- **ABI and layout breakage within a minor series:**
  - Issue #311 (opened 2026-06-06): `set_hl` panics on nvim 0.12.2 with a non-recoverable "panic in a function that cannot unwind". The cause is that the `#[repr(C)] SetHighlightOpts` struct still mirrors Neovim 0.11.3's keyset, while 0.12 added 5 fields, reordered the booleans, and changed `cterm` to a sub-dict.
  - The reporter submitted fix PR #312 the same day. The thread shows no maintainer response. — [Issue #311](https://github.com/noib3/nvim-oxi/issues/311)
  - Other open issues from April 2026:
    - #309 "`create_autocmd` broken on Neovim 0.12.2"
    - #298 "Cannot open split window with Neovim 0.12.0"
    - #299 "Panic when getting keymaps"
    - #305 "Window::call panics if I call further api functions within callback"
    - PR #307 "Rename buffer to buf for autocmds' api (0.12.2)"
  - [nvim-oxi open issues](https://github.com/noib3/nvim-oxi/issues)
- **Long-open feature requests** show incomplete API coverage: `vim.ui` (#40), `vim.lsp` (#47), `vim.diagnostic` (#48) since July 2022, treesitter support (#181, 2024), and "Better integration with mlua" (#72, 2022). Memory and soundness issues are also open: "The memory leak of the luajit::function::remove" (#283), "Arena is not free" (#284), and "Structures such as Buffer, Window, etc. should not be sent" (#282). On Windows, there are "Windows compilation issues when `libuv` turned on" (#234). — [nvim-oxi open issues](https://github.com/noib3/nvim-oxi/issues)
- **Documentation:** docs.rs API docs, an `examples/` directory, and a `#[nvim_oxi::test]` macro that runs tests inside a spawned Neovim instance. The README invites users to "open a new issue and I might add a new example". — [nvim-oxi README](https://github.com/noib3/nvim-oxi)
- **Fork:** contributor c-c-k maintains **nvimo**, a fork that replaces nvim-oxi's own Lua bindings with mlua. It cites mlua's "Robust error and panic propagation across the Rust-Lua boundary" and lua-ls type generation via mlua-extras. It has 880 commits and no releases. — [c-c-k/nvimo](https://github.com/c-c-k/nvimo)

### Inferences
- Bus factor is about 1. noib3's attention appears focused on nomad, which consumes nvim-oxi from git master, so the crates.io release lag hurts third-party users more than the author.
- nvim-oxi binds Neovim's C API by mirroring `Dict(...)` keyset structs as `#[repr(C)]`. Any change to a keyset can therefore cause UB or an abort, even in a Neovim **patch** release, as 0.12.2 did. This is the core structural maintenance burden. It explains per-Neovim-version cargo features and nomad's per-version binaries.
- The "fully typed API" is both the selling point and the liability: each typed opts struct must be kept in lockstep with Neovim.

### Gaps
- I did not determine the precise symbol-linking mechanism or whether nvim-oxi binaries load on Windows in practice. Windows-specific issues exist (#234), and nomad ships no Windows builds.
- I found no public statement from noib3 on release plans for 0.7 or on the current maintenance status.

## Alternatives and trade-offs

### Takeaway
For most Rust-in-Neovim use cases in 2026, **mlua in module mode** is the de facto standard: the highest-star plugins use it, and its adoption is about 130 times nvim-oxi's by downloads. It loads as a LuaJIT C module, so it is bound to Lua's stable C ABI rather than Neovim's internal structs. **nvim-oxi** adds typed, direct access to the Neovim C API at the cost of version coupling. **RPC (nvim-rs)** gives process isolation and version independence but is limited and slower for interactive callbacks. WASM remains experimental.

### Cited Findings
- **mlua:**
  - Supports Lua 5.1–5.5, LuaJIT, and Luau. It "allows writing native Lua modules in Rust" through the `module` feature ("building loadable `cdylib` library for Lua") and is "tested on Windows/macOS/Linux including module mode".
  - On macOS, module mode needs `-C link-arg=-undefined -C link-arg=dynamic_lookup`.
  - mlua warns that module mode "uses an external Lua runtime which could lead to potential unsafety due to the unpredictability of the Lua environment". — [mlua README](https://github.com/mlua-rs/mlua)
- **mlua metrics, 2026-10-11:** 2,897 stars, last push 2026-10-03, version 0.12.2, 7.70M total downloads and 2.17M recent. — [GitHub API](https://api.github.com/repos/mlua-rs/mlua); [crates.io API](https://crates.io/api/v1/crates/mlua)
- **nvim-oxi's own pitch against RPC:** RPC means having "to (de)serialize everything to MessagePack-encoded messages, prohibiting things like attaching callbacks to keymaps or scheduling functions." nvim-oxi "leverages Rust's foreign function interface (FFI) support to hook straight into the Neovim C code, allowing feature parity with 'in process' plugins while also avoiding the need for an extra IO layer." Its two stated reasons are access to the Rust ecosystem and a "fully typed API… checked at compile-time". — [nvim-oxi README](https://github.com/noib3/nvim-oxi)
- **nvim-oxi interop with mlua:** an optional `mlua` feature exists, but issue #258 "Cannot build with `mlua` enable" and #286 "Dependency on mlua/module feature" are open. — [nvim-oxi Cargo.toml](https://raw.githubusercontent.com/noib3/nvim-oxi/main/Cargo.toml); [issues](https://github.com/noib3/nvim-oxi/issues)
- **nvim-rs (RPC):**
  - "Rust library for Neovim msgpack-rpc clients. Utilizes async to allow for arbitrary nesting of requests." Its API is described as "unstable". It is a fork of neovim-lib under LGPL-3.0, with new commits dual-licensed Apache/MIT. — [nvim-rs README](https://github.com/KillTheMule/nvim-rs)
  - Metrics: 270 stars, last push 2026-06-13, version 0.9.2 (2025-03-23), 209k total downloads and 49k recent. — [GitHub API](https://api.github.com/repos/KillTheMule/nvim-rs); [crates.io API](https://crates.io/api/v1/crates/nvim-rs)
- **neovim-lib:** 192 stars, last push **2019-09-01**, so it is effectively abandoned. — [GitHub API](https://api.github.com/repos/daa84/neovim-lib)
- **nvim-utils** (a helper around mlua) is "no longer maintained. For a more polished API, check out nvim-oxi." — [willothy/nvim-utils](https://github.com/willothy/nvim-utils)
- **WASM:**
  - Borwe/wasm_nvim is a Rust library bridging Lua and wasm to avoid RPC's inter-process bottleneck. Its only benchmark is a trivial summing loop. I found no official Neovim WASM plugin proposal. — [Borwe/wasm_nvim](https://github.com/Borwe/wasm_nvim)
  - mlua supports WASM only via `wasm32-unknown-emscripten`, excluding JIT. — [mlua README](https://github.com/mlua-rs/mlua)
- **Distribution friction with native modules, even with mlua:** a blink.cmp discussion covers a `luaopen_blink_cmp_fuzzy` "symbol not found" load error. The suggested fixes are deleting and redownloading the library, checking its architecture with `ldd`, or building with Rust nightly. — [blink.cmp discussion #2299](https://github.com/saghen/blink.cmp/discussions/2299)
- **Packaging:** nixpkgs builds blink.cmp's Rust lib separately as `blink-fuzzy-lib` via `rustPlatform.buildRustPackage`, with per-release Cargo hashes. — [nixpkgs commit](https://code.ornl.gov/nix/nixpkgs/-/commit/226216574ada4c3ecefcbbec41f39ce4655f78ef)

### Comparison summary (synthesized from the findings above)
| Approach | Coupling | API access | Callbacks and scheduling | Distribution | Cross-platform evidence | Ecosystem size (2026-10) |
|---|---|---|---|---|---|---|
| nvim-oxi (cdylib, direct C API) | Neovim version (per-version features; struct layouts can break in patch releases) | Typed Rust wrappers of `nvim_*`; gaps for vim.lsp, vim.ui, vim.diagnostic, treesitter | Yes, in-process | Per-Neovim-version × per-platform binaries, or cargo (nomad needs nightly) | Linux and macOS shipped by nomad; Windows issues open | 1.1k stars, 58k downloads |
| mlua module mode (cdylib, Lua C API) | LuaJIT/Lua C ABI (stable); Neovim API reached through Lua `vim.*` | Anything Lua can call, untyped | Yes, in-process | One binary per platform; Lua fallback possible | blink.cmp ships Linux, macOS, Windows, BSD, Android | 2.9k stars, 7.7M downloads |
| LuaJIT FFI to a Rust C-ABI lib | C ABI you define | Lua side calls `vim.*` | Lua side | Same as cdylib | (no specific source found) | n/a |
| RPC (nvim-rs) | msgpack-RPC API (stable, versioned) | Full RPC API | Limited (no direct keymap callbacks per the nvim-oxi README); IPC latency | A separate binary; no ABI coupling | Async Rust; any OS | 270 stars, 209k downloads |
| Pure Lua (or Fennel/Teal compiled to Lua) | None | Full | Native | No build step | Universal | Dominant |
| WASM | Experimental | Via a custom bridge | n/a | n/a | n/a | Negligible |

### Inferences
- Choosing mlua over nvim-oxi decouples the binary from Neovim's internal keyset structs. Only Lua's C API is involved, and LuaJIT's 5.1 ABI is frozen. This is likely why the large distributed plugins (blink.cmp, avante, fff) chose mlua and can ship one artifact per OS and arch.
- Startup cost: both cdylib approaches load via `require` with no process spawn, while RPC requires spawning and connecting a child process. I found no published benchmarks.
- Safety:
  - nvim-oxi's typed API catches misuse at compile time, but a layout mismatch causes an abort across the FFI boundary that cannot unwind (#311).
  - mlua propagates Rust panics and errors into Lua errors, which nvimo cites as a reason to switch.
  - RPC isolates crashes in a separate process.

### Gaps
- I found no independent benchmarks comparing nvim-oxi, mlua, and RPC call overhead or startup time.
- I found no documentation of a Lua/Teal/Fennel versus Rust comparison specific to 2026.
- I found no examples or sources for the LuaJIT FFI to a Rust C-ABI approach.

## Community sentiment

### Takeaway
Public discussion of nvim-oxi is sparse. I found no r/neovim threads through search, and Hacker News mentions are a few comments. Early reception (2022) was enthusiastic. Recent signals of pain come from the issue tracker (0.12 breakage, panics, memory leaks, build problems with the mlua and libuv features) and from a contributor fork, rather than from forums.

### Cited Findings
- **HN, 2022-08-10:** a commenter wrote "now that nvim-oxi has come out, I am going to use it even less [Lua]", and a reply said: "Woah, interesting ... I'm imagining it could lead to a really slick and responsive editing experience". — [HN item 32409080](https://news.ycombinator.com/item?id=32409080)
- **HN, 2022-08-10, same thread, on Lua's shortcomings:** "No static typing, No ergonomic language features like lambdas… magic nil behaviour, global by default". This is the motivation side of the case for Rust. — [HN item 32408957](https://news.ycombinator.com/item?id=32408957)
- **HN, 2026-02-15:** a commenter recommends Denops (Deno/TypeScript over RPC) as "super easy to use, works great. Connects over RPC". This is an example of people choosing RPC hosts for non-Lua plugins. — [HN item 47021294](https://news.ycombinator.com/item?id=47021294)
- **Pain points from the tracker:**
  - "Neovim crashing on errors" (#231)
  - "Share a trap I encountered" (#278)
  - "Cannot build with `mlua` enable" (#258)
  - "libuv feature error" (#249)
  - Windows compilation with libuv (#234)
  - 0.12.x breakages (#298, #309, #311)
  - [nvim-oxi issues](https://github.com/noib3/nvim-oxi/issues)
- **The nvimo fork's README** praises nvim-oxi's design but moves to mlua for error and panic propagation. — [c-c-k/nvimo](https://github.com/c-c-k/nvimo)
- **Build friction for end users:** nomad requires lazy.nvim, plus nightly Rust or Nix for source builds. — [nomad installation.md](https://raw.githubusercontent.com/nomad/nomad/main/docs/installation.md)
- blink.cmp users hit native library load errors ("symbol not found"). — [blink.cmp discussion #2299](https://github.com/saghen/blink.cmp/discussions/2299)

### Inferences
- Compile time is likely a developer-side pain, given nomad's large dependency tree and the nightly toolchain, but I found no explicit complaints.
- The near absence of forum discussion, together with low reverse-dependency counts, suggests nvim-oxi remains a niche tool for Rust enthusiasts rather than a mainstream plugin-authoring path.

### Gaps
- Reddit's search API was blocked and WebSearch returned no r/neovim threads. neovim.discourse.group did not resolve, so the original "Calling Neovim internal functions with LuaJIT FFI and Rust" thread, which the nvim-oxi README links, could not be read.
- I found no blog posts or conference talks specifically about building with nvim-oxi.

## When Rust (via nvim-oxi) is justified versus overkill

### Takeaway
Rust is justified when a plugin has substantial **compute or systems work** (fuzzy matching over 10k+ items, CRDTs and networking, file indexing, parsing) or needs crates Lua lacks. Even then, the dominant successful pattern is mlua with a Lua frontend and a Lua fallback. nvim-oxi specifically is justified when you want a mostly-Rust plugin that calls many Neovim APIs with compile-time types, **and** you can absorb per-Neovim-version builds and track nvim-oxi master. For UI-glue plugins, keymaps, and small utilities it is overkill, and pure Lua avoids every distribution problem.

### Cited Findings
- **Compute-heavy wins:** blink.cmp's Rust matcher handles "10k+ items", is typo-resistant, and claims about 6x fzf's speed, while keeping a Lua implementation as a fallback. — [blink.cmp fuzzy docs](https://cmp.saghen.dev/configuration/fuzzy)
- **A systems-heavy plugin on nvim-oxi:** nomad's real-time collaboration uses CRDTs, async networking, TLS, and a keyring. Its dependency list would be hard to replicate in Lua. — [nomad Cargo.toml](https://raw.githubusercontent.com/nomad/nomad/main/Cargo.toml)
- **The cost side:**
  - Per-Neovim-version binaries and no Windows builds. — [nomad releases](https://api.github.com/repos/nomad/nomad/releases)
  - Crashes on patch-version struct changes (#311). — [Issue #311](https://github.com/noib3/nvim-oxi/issues/311)
  - No crates.io release with 0.12 support. — [crates.io API](https://crates.io/api/v1/crates/nvim-oxi)
- **nvim-oxi's own rationale:** the Rust ecosystem and a typed API. It notes that Lua "can also be limiting when writing more complex plugins". — [nvim-oxi README](https://github.com/noib3/nvim-oxi)

### Inferences
- **Decision heuristic:**
  1. Default to Lua.
  2. If a hot path is CPU-bound or needs a Rust crate, add an mlua module with prebuilt binaries per OS and arch and a Lua fallback (the blink.cmp, fff, and avante pattern).
  3. Use nvim-oxi only if most of the plugin logic must drive the Neovim API from Rust (nomad-style), you target a narrow range of Neovim versions, and you accept a pinned git dependency on a single-maintainer project.
  4. Use RPC (nvim-rs) when process isolation or independence from Neovim versions matters more than callback latency, or when the tool also needs to run outside Neovim.
- For a new project in October 2026, nvim-oxi's maintenance signals point to a fork or a pinned git revision with your own patches as the realistic way to depend on it. Those signals are: no release in about 17 months, no master commits in about 5 months, and unmerged 0.12.x fix PRs.

### Gaps
- I found no first-hand postmortems from authors who abandoned nvim-oxi, beyond the circumstantial evidence of Saghen's move to mlua and the nvimo fork.
