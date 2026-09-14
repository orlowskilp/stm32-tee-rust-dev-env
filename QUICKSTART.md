# Quickstart

Get a Rust TA + host app building and running on your STM32MP2 board in five steps.

## Prerequisites

- STM32MP2 board with OP-TEE OS running (you have already verified with the C `hello_world` example).
- The Yocto SDK extracted to `/opt/sdk/`.
- Rust toolchain installed (`rustup` available on `PATH`).

```bash
# Source the SDK environment so cross-compilation variables are set.
source .envrc
```

This sets `CROSS_COMPILE`, `TA_DEV_KIT_DIR`, `OPTEE_CLIENT_EXPORT`, `BOARD_ADDRESS`, and the sysroot paths.

## Step 1 — Clone the TrustZone SDK

```bash
cd crates
git clone https://github.com/apache/teaclave-trustzone-sdk.git trustzone-sdk
```

This pulls the Apache Teaclave TrustZone SDK, which provides the Rust bindings for OP-TEE (`optee-utee` for TAs, `optee-teec` for host apps).

> **Note:** The SDK crates are pinned to OP-TEE 4.10.0. Verify that your STM32MP2 SDK ships the matching OP-TEE version.

## Step 2 — Build

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

## Step 3 — Deploy

```bash
make deploy BOARD_ADDRESS=<your-board-address>
```

This SCPs the signed TA binary to `/usr/lib/tee-datasync/` on the board and the host app to `/root/`.

Alternatively, do it by hand:

```bash
# Deploy the TA
scp ta/target/aarch64-unknown-linux-gnu/release/$(cat ta/uuid.txt).ta root@<your-board-address>:/usr/lib/tee-datasync/

# Deploy the host app
scp host_app/target/aarch64-unknown-linux-gnu/release/hello_world_host root@<your-board-address>:/root/
```

## Step 4 — Run

```bash
ssh root@<your-board-address> ./hello_world_host
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
├── ta/                       # Trusted Application (runs in Secure World)
│   ├── Cargo.toml            # rustc target + optee-utee deps
│   ├── src/main.rs           # TA entry points: create, open_session, invoke_command, close_session, destroy
│   └── uuid.txt              # TA UUID (128-bit)
├── host_app/                 # Host application (runs in Normal World / Linux)
│   ├── Cargo.toml            # optee-teec deps
│   ├── build.rs              # Cross-compilation metadata
│   └── src/main.rs           # Opens session, invokes commands, reads results
├── crates/
│   └── trustzone-sdk/        # Apache Teaclave SDK (cloned in Step 1)
├── Makefile                  # Top-level build: ta, host, clean, deploy
├── rust-toolchain.toml       # Rust toolchain config (already present)
└── .envrc                    # SDK environment setup (already present)
```

## Architecture

```text
┌──────────────────────────────────────────┐
│  STM32MP2 Normal World (Linux)           │
│                                          │
│  host_app/src/main.rs                    │
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

Edit `ta/uuid.txt` and update the `TA_UUID` constant in `host_app/src/main.rs` to match. The UUID must be identical in both places.

### Add new commands

In `ta/src/main.rs`, add a new constant to `TA_CMD_*` and a new arm to the `match` in `ta_invoke_command()`. In the host app, add the matching constant and call `session.invoke_command()` with the new command ID.

### Use parameter types other than values

The TA and host both use `ParameterValueInout` / `ParamValue` in this example. For shared memory transfers, use `ParamMemRef` types instead. The Teaclave SDK provides `ParamTmpRef`, `ParamMemRef`, and their variants in the `optee-teec` crate.

## Known Constraints

- **OP-TEE version:** The Teaclave SDK crates target OP-TEE 4.10.0. Version mismatches between the SDK bindings and the OP-TEE runtime on your board will cause ABI issues.
- **No-std:** The TA builds with `no_std` (stable Rust). The `std` feature (requires nightly) is available for advanced features like TLS inside a TA.
- **Cross-compilation:** Everything is cross-compiled for `aarch64-unknown-linux-gnu`. Do not run `cargo build` without the target flag — it will target your host architecture instead.

## Further Reading

- [Apache Teaclave TrustZone SDK](https://github.com/apache/teaclave-trustzone-sdk) — the upstream project containing the Rust bindings and 20+ TA/CA examples.
- [OP-TEE Documentation](https://optee.readthedocs.io) — the official OP-TEE reference.
