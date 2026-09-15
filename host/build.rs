//! Build script for hello world host application.
//!
//! Configures cross-compilation metadata and linker flags for OP-TEE host apps.

use std::{env, fs, path::Path};

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

    let uuid_raw = fs::read_to_string("uuid.txt").expect("uuid.txt present in the host crate root");
    let uuid = uuid_raw.trim();
    assert!(!uuid.is_empty(), "uuid.txt must not be empty");
    assert_eq!(
        uuid.len(),
        36,
        "UUID must be 36 characters (8-4-4-4-12 format)"
    );
    for (i, c) in uuid.chars().enumerate() {
        match i {
            8 | 13 | 18 | 23 => assert_eq!(c, '-', "UUID must have dash at position {i}"),
            _ => assert!(
                c.is_ascii_hexdigit(),
                "UUID must contain only hex characters at position {i}, got '{c}'"
            ),
        }
    }

    let out_dir = env::var("OUT_DIR").expect("OUT_DIR");
    let uuid_out = Path::new(&out_dir).join("read_uuid.rs");
    let code = format!("pub const TA_UUID: &str = \"{}\";", uuid);
    fs::write(&uuid_out, &code).expect("Failed to write read_uuid.rs to OUT_DIR");

    // Link against libteec.so. The optee-teec crate provides the FFI bindings;
    // we emit the linker flag here so cargo handles it during cross-compilation
    // (avoids the `-C link-arg=...` syntax which cargo 1.98 rejects on CLI).
    println!("cargo:rustc-link-lib=teec");

    // Rebuild if environment changes.
    println!("cargo:rerun-if-env-changed=TA_DEV_KIT_DIR");
    println!("cargo:rerun-if-env-changed=OPTEE_CLIENT_EXPORT");
    println!("cargo:rerun-if-env-changed=CROSS_COMPILE");
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");
    let source_uuid = Path::new(&manifest_dir)
        .parent()
        .expect("CARGO_MANIFEST_DIR should have a parent")
        .join("ta")
        .join("uuid.txt");
    println!(
        "cargo:rerun-if-changed={}",
        source_uuid.to_str().expect("valid path")
    );
}
