//! Build script for the hello world TA (Trusted Application)
//!
//! Configures cross-compilation metadata and linker flags for the TA.

use optee_utee_build::{Builder, LinkerType, TaConfig};
use std::{process, fs, path::Path, env};

fn main() {
    let uuid = fs::read_to_string("uuid.txt").expect("uuid.txt");
    let ta_config = TaConfig::new_default(uuid.trim(), "0.1.0", "Hello World")
        .expect("ta config");
    // gcc-ld is the linker driver (rustc passes -B.../gcc-ld -fuse-ld=lld),
    // so args need the -Wl, prefix even though the underlying linker is lld.
    // rust-lld resolves --dynamic-list relative to OUT_DIR at link time, but
    // with gcc as driver it can't find files there. Copy dyn_list to CWD so
    // the linker finds it.
    if let Err(err) = Builder::new(ta_config)
        .linker_type(LinkerType::Cc)
        .build()
    {
        eprintln!("Build error: {err:?}");
        process::abort();
    }

    // Copy dyn_list from OUT_DIR to the TA crate root so rust-lld can find it.
    // When rust-lld is invoked through gcc as the linker driver, it resolves
    // --dynamic-list relative to CWD (not OUT_DIR). Copying to CARGO_MANIFEST_DIR
    // ensures it's found regardless of where make is run from.
    let out_dir = env::var("OUT_DIR").expect("OUT_DIR");
    let dyn_list_src = Path::new(&out_dir).join("dyn_list");
    let dyn_list_dst = Path::new(env!("CARGO_MANIFEST_DIR")).join("dyn_list");
    if dyn_list_src.is_file() {
        fs::copy(&dyn_list_src, &dyn_list_dst).ok();
    }
}
