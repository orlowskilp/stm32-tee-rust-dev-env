# Quickstart

Get a Rust TA + host app building and running on your STM32MP2 board in four steps.

## Prerequisites

- STM32MP2 board with OP-TEE OS running (you have already verified with the C `hello_world` example).
- **Yocto SDK** — the STM32MP2 OpenSTLinux SDK (with optional Rust add-ons) containing the `aarch64-ostl-linux-` cross-compiler toolchain. The SDK tarballs (`SDK-x86_64-stm32mp2-openstlinux-6.6-yocto-scarthgap-mpu-*.tar.gz` and `SDK-x86_64-stm32mp2-openstlinux-6.6-v26.06.10-addon-rust.tar.gz`) are necessary and can be configured via the `SDK_TARBALL_FILE` and `SDK_RUST_ADDON_FILE` variables in `.devcontainer/devcontainer.json`. Download them from the [STM32MP2 Getting Started page](https://wiki.st.com/stm32mpu/wiki/Getting_started/STM32MP2_boards/STM32MP257x-DK/Develop_on_Arm_Cortex-A35/Install_the_SDK).
- **Rust toolchain** installed (`rustup` available on `PATH`)
- **`uuidgen`** installed — used by `make init` to generate a TA UUID

All cross-compilation environment variables (`CROSS_COMPILE`, `TA_DEV_KIT_DIR`, `OPTEE_CLIENT_EXPORT`, `BOARD_ADDRESS`, and the sysroot paths) are set by sourcing `.envrc` — a file native to [direnv](https://direnv.net/), which the devcontainer uses to configure the workspace on every shell entry.

```bash
# Bootstrap environment from the example file (not tracked in git).
cp .envrc.example .envrc

# Source the SDK environment so cross-compilation variables are set.
source .envrc
```

## Step 0 (optional) — Initialize

Generate a UUID for the TA and populate `ta/uuid.txt`:

```bash
make init
```

## Step 1 — Build

```bash
# Build the Trusted Application (TA) — produces a signed .ta binary.
make ta

# Build the host application for ARM64.
make host
```

### TA Signing

The `make ta` target signs the TA binary using `sign_encrypt.py`.
Both the signing script and the default signing key are configured by the Makefile's
variable defaults, which source paths from `.envrc`.
Override `TA_SIGN_KEY` only when using a custom key.

```bash
make ta TA_SIGN_KEY=/path/to/key.pem
```

#### RSA Signing Keys

The default test key shipped by the SDK at `$(TA_DEV_KIT_DIR)/keys/default_ta.pem`
(resolving to `/opt/sdk/sysroots/cortexa35-ostl-linux/usr/include/optee/export-user_ta_arm64/keys/default_ta.pem`)
is a 2048-bit RSA key suitable for development. The default signing algorithm is
`TEE_ALG_RSASSA_PKCS1_PSS_MGF1_SHA256` — RSA-PSS with SHA-256.

For production, the board requires a unique TA signing key. The board's OP-TEE OS
was built with a specific key embedded in the core, and TAs must be signed with the
matching private key.

Generate a new key pair:

```bash
openssl genrsa -out my_ta_key.pem 2048
openssl rsa -in my_ta_key.pem -pubout -out my_ta_key_pub.pem
```

Use it with `make ta TA_SIGN_KEY=/path/to/my_ta_key.pem`.
To use the default SDK key, run `make ta` without overrides — it is the Makefile default.

RSA is the only supported signing algorithm for TAs. ECDSA is not supported by
OP-TEE's TA signature mechanism.

## Step 2 — Deploy

```bash
make deploy BOARD_ADDRESS=<your-board-address>
```

This SCPs the signed TA binary to the board's TA store (`/lib/optee_armtz/`), deploys the host app to `~`, and immediately runs it via `sudo`. To deploy without running, do it manually:

```bash
# Deploy the TA
scp ta/target/aarch64-unknown-linux-gnu/release/$(cat ta/uuid.txt).ta root@<your-board-address>:/lib/optee_armtz/

# Deploy the host app
scp host/target/aarch64-unknown-linux-gnu/release/hello-world-host root@<your-board-address>:/root/
```

## Step 3 — Run

```bash
ssh root@<your-board-address> sudo ./hello-world-host
```

Expected output:

```text
Sending value to TA: 42
TA echoed (incremented) value to 43
TA decreased value back to 42
Done
```

You should also see the TA's log output in the secure log:

```bash
# On the board
journalctl -k | grep optee
# or
dmesg | grep optee
```

## Project Structure

```text
.
├── ta/           # Trusted Application (runs in Secure World, nightly Rust)
├── host/         # Host application (runs in Normal World, stable Rust)
├── .devcontainer/ # Devcontainer config (Dockerfile, VS Code settings)
└── .vscode/      # VS Code workspace settings
```

## Architecture

```text
┌──────────────────────────────────────────┐
│  STM32MP2 Normal World (Linux)           │
│                                          │
│  host/src/main.rs                        │
│    └─→ optee-teec (crate)                │
│         └─→ libteec.so (OP-TEE Client)   │
│              └─→ TEE driver (kernel) ────┼──► Secure World
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  STM32MP2 Secure World (OP-TEE TEE)      │
│                                          │
│  ta/src/main.rs                          │
│    └─→ optee-utee (crate)                │
│         └─→ libutee.a (OP-TEE TA API)    │
│              └─→ OP-TEE OS core          │
└──────────────────────────────────────────┘
```

## Customizing

### Change the TA UUID

Edit `ta/uuid.txt`. The host's `build.rs` reads `uuid.txt` at build time and generates `read_uuid.rs` containing the `TA_UUID` constant, so no source file changes are needed in the host app — just rebuild.

### Add new commands

In `ta/src/main.rs`, add a new variant to the `Command` enum and a new arm to the `match` in `ta_invoke_command()`. In the host app, add the matching enum variant and call `session.invoke_command()` with it.

### Use parameter types other than values

The TA and host both use `ParamValue` with `ParamType::ValueInout` in this example. For shared memory transfers, use `ParamMemRef` types instead. The Teaclave SDK provides `ParamTmpRef`, `ParamMemRef`, and their variants in the `optee-teec` crate.

## Known Constraints

- **OP-TEE version:** The Teaclave SDK crates target OP-TEE 4.10.0 (via `v0.9.0` tag). Version mismatches between the SDK bindings and the OP-TEE runtime on your board will cause ABI issues.
- **No-std:** The TA builds with `no_std` by default (requires nightly Rust via `ta/rust-toolchain.toml`). The `std` feature is available for advanced features like TLS inside a TA.
- **Cross-compilation:** Both sub-projects have `[build] target` configured in `.cargo/config.toml` set to `aarch64-unknown-linux-gnu`, so `cargo build` from within the `ta/` or `host/` directory will automatically target ARM64.
- **Per-subproject toolchain:** The TA uses nightly Rust (`ta/rust-toolchain.toml`) and the host uses stable (`host/rust-toolchain.toml`).

## Further Reading

- [Apache Teaclave TrustZone SDK](https://github.com/apache/teaclave-trustzone-sdk) — the upstream project containing the Rust bindings and 20+ TA/CA examples.
- [OP-TEE Documentation](https://optee.readthedocs.io) — the official OP-TEE reference.

---

Copyright (c) 2026 Lukasz P Orlowski <lukasz@orlowski.io>. All rights reserved.
