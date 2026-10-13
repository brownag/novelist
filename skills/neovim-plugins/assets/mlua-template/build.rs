// macOS: leave lua_* symbols unresolved; they bind to nvim's exports at load time.
// Checks the *target* OS so cross-compiling from Linux still works.
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-cdylib-link-arg=-undefined");
        println!("cargo:rustc-cdylib-link-arg=dynamic_lookup");
    }
}
