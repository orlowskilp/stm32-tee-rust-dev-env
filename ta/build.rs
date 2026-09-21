// SPDX-License-Identifier: MIT

//! Build script for the hello world TA (Trusted Application)
//!
//! Configures cross-compilation metadata and linker flags for the TA.

use optee_utee_build::{Builder, LinkerType, TaConfig};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process,
};

fn validate_uuid(uuid: &str) {
    let uuid = uuid.trim();
    assert!(
        !uuid.is_empty(),
        "UUID must not be empty — check ta/uuid.txt"
    );
    assert_eq!(
        uuid.len(),
        36,
        "UUID must be exactly 36 characters (8-4-4-4-12 format), got {}",
        uuid.len()
    );
    // Verify basic format: 8-4-4-4-12 hex groups with dashes at positions 8, 13, 18, 23
    for (i, c) in uuid.chars().enumerate() {
        match i {
            8 | 13 | 18 | 23 => {
                assert_eq!(c, '-', "UUID must have dash at position {i}, got '{c}'")
            }
            _ => assert!(
                c.is_ascii_hexdigit(),
                "UUID must contain only hex characters at position {i}, got '{c}'"
            ),
        }
    }
}

fn main() {
    // Read UUID from the TA crate root — same directory as build.rs.
    let uuid =
        fs::read_to_string("uuid.txt").expect("uuid.txt must be present in the TA crate root");
    validate_uuid(&uuid);
    let ta_config = TaConfig::new_default(uuid.trim(), "0.1.0", "Hello World").expect("TA config");
    // gcc-ld is the linker driver (rustc passes -B.../gcc-ld -fuse-ld=lld),
    // so args need the -Wl, prefix even though the underlying linker is lld.
    // The Builder emits `--dynamic-list=dyn_list` which is relative to CWD.
    // Since cargo runs from the workspace root, CWD is the workspace root.
    if let Err(err) = Builder::new(ta_config).linker_type(LinkerType::Cc).build() {
        eprintln!("Build error: {err:?}");
        process::abort();
    }

    // Copy dyn_list from OUT_DIR to the workspace root so rust-lld can find it.
    // When rust-lld is invoked through gcc as the linker driver, it resolves
    // --dynamic-list relative to CWD (not OUT_DIR). When cargo is invoked from the
    // workspace root, CWD is the workspace root, so we copy dyn_list there.
    //
    // Note: CARGO_MANIFEST_DIR points to the TA crate root (ta/). We traverse
    // one parent to reach the workspace root. This invariant assumes the TA crate
    // is always a direct child of the workspace root.
    let out_dir = env::var("OUT_DIR")
        .expect("OUT_DIR environment variable not set — this should be set by cargo during build");
    let dyn_list_src = PathBuf::from(&out_dir).join("dyn_list");
    if !dyn_list_src.is_file() {
        panic!(
            "dyn_list not found in OUT_DIR ({out_dir}); the optee-utee-build Builder should have created it",
        );
    }
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect(
        "CARGO_MANIFEST_DIR environment variable not set — this should be set by cargo during build",
    );
    let dyn_list_dst = Path::new(&manifest_dir)
        .parent()
        .expect("CARGO_MANIFEST_DIR should have a parent")
        .join("dyn_list");
    fs::copy(&dyn_list_src, &dyn_list_dst)
        .unwrap_or_else(|_| panic!("failed to copy {dyn_list_src:?} to {dyn_list_dst:?}"));

    // Rebuild if uuid.txt changes or the build script itself changes.
    println!("cargo:rerun-if-changed=uuid.txt");
    println!("cargo:rerun-if-changed=build.rs");
}
