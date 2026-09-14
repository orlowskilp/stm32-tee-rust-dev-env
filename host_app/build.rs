//! Build script for hello_world_host.
//!
//! Reads TA_DEV_KIT_DIR from the environment.
//! If the optee-teec-build crate is available, it can be used here for
//! cross-compilation metadata. For now this is a minimal placeholder.

use std::env;

fn main() {
    let ta_dev_kit = env::var("TA_DEV_KIT_DIR").unwrap_or_else(|_| "<not set>".to_string());
    println!("cargo:warning=TA_DEV_KIT_DIR={}", ta_dev_kit);

    // Placeholder: optee-teec-build integration can be wired here once the
    // submodule is cloned and the build system is validated.
}
