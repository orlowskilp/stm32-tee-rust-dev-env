//! Build script for hello_world_host.
//!
//! Configures cross-compilation metadata and linker flags for OP-TEE host apps.

use std::env;

fn main() {
    // ── Cross-compilation metadata ──────────────────────────────────────────
    let ta_dev_kit = env::var("TA_DEV_KIT_DIR").unwrap_or_else(|_| "<not set>".to_string());
    println!("cargo:warning=TA_DEV_KIT_DIR={}", ta_dev_kit);

    // Tell cargo where to find libteec.so during cross-linking.
    // OPTEE_CLIENT_EXPORT is set by the Yocto SDK environment (sourced from .envrc).
    if let Ok(client_export) = env::var("OPTEE_CLIENT_EXPORT") {
        println!("cargo:rustc-link-search=native={}/lib", client_export);
        println!("cargo:rerun-if-env-changed=OPTEE_CLIENT_EXPORT");
    }

    // Link against libteec.so. The optee-teec crate provides the FFI bindings;
    // we emit the linker flag here so cargo handles it during cross-compilation
    // (avoids the `-C link-arg=...` syntax which cargo 1.98 rejects on CLI).
    println!("cargo:rustc-link-lib=teec");

    // Rebuild if environment changes.
    println!("cargo:rerun-if-env-changed=TA_DEV_KIT_DIR");
    println!("cargo:rerun-if-env-changed=OPTEE_CLIENT_EXPORT");
    println!("cargo:rerun-if-env-changed=CROSS_COMPILE");
}
