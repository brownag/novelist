//! Thin mlua glue. Keep real logic in plain Rust (ideally a separate crate)
//! so it can be tested with `cargo test`; this file only converts values.
use mlua::prelude::*;
use serde::Deserialize;

/// Options table deserialized straight from Lua via the `serde` feature.
#[derive(Deserialize, Default)]
struct Opts {
    #[serde(default)]
    min_len: usize,
}

/// Stateful object exposed to Lua as userdata: `local c = m.counter(); c:add("..."); c.total`.
struct Counter {
    total: usize,
}

impl LuaUserData for Counter {
    fn add_fields<F: LuaUserDataFields<Self>>(fields: &mut F) {
        fields.add_field_method_get("total", |_, this| Ok(this.total));
    }
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("add", |_, this, text: LuaString| {
            this.total += text.to_str()?.split_whitespace().count();
            Ok(this.total)
        });
    }
}

/// Pure computation: the kind of work worth doing in Rust.
fn word_count(lua: &Lua, (text, opts): (LuaString, Option<LuaValue>)) -> LuaResult<usize> {
    let opts: Opts = match opts {
        Some(v) => lua.from_value(v)?,
        None => Opts::default(),
    };
    Ok(text
        .to_str()?
        .split_whitespace()
        .filter(|w| w.chars().count() >= opts.min_len)
        .count())
}

/// Calling the editor from Rust works (it's just Lua tables) but is untyped and
/// no faster than Lua. Prefer passing data in from Lua; shown here for reference.
fn current_line(lua: &Lua, _: ()) -> LuaResult<String> {
    let vim: LuaTable = lua.globals().get("vim")?;
    let api: LuaTable = vim.get("api")?;
    api.get::<LuaFunction>("nvim_get_current_line")?.call(())
}

/// Returning Err raises a normal Lua error that `pcall` can catch.
fn fail(_: &Lua, _: ()) -> LuaResult<()> {
    Err(LuaError::runtime("boom from rust"))
}

// Exports `luaopen_myplugin_native`. Neovim maps require("a.b") to luaopen_a_b,
// so a file at lua/myplugin/native.so with require("myplugin.native") would need
// name = "myplugin_native" too. `name` must be a Rust identifier (no dots/dashes).
// skip_memory_check: skips per-call allocation checks; recommended under nvim.
#[mlua::lua_module(name = "myplugin_native", skip_memory_check)]
fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let t = lua.create_table()?;
    t.set("word_count", lua.create_function(word_count)?)?;
    t.set("current_line", lua.create_function(current_line)?)?;
    t.set("fail", lua.create_function(fail)?)?;
    t.set("counter", lua.create_function(|_, ()| Ok(Counter { total: 0 }))?)?;
    Ok(t)
}
