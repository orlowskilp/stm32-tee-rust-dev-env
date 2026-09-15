#!/usr/bin/env bash
# ── cargo-linker-wrapper.sh ─────────────────────────────────────────────────────
# Wrapper around the cross-compiler gcc that injects --sysroot so cargo can find
# C runtime startup files (Scrt1.o, crti.o, crtbeginS.o) during linking.
#
# Cargo invokes the linker as: wrapper -Wl,... <other args>
# We prepend --sysroot and delegate to the real cross-compiler.
#
# Environment variables (set by Yocto SDK environment-setup):
#   OECORE_TARGET_SYSROOT  — target sysroot path (preferred)
#   SDKTARGETSYSROOT       — alternative name, same value
#
# Falls back to /opt/sdk/sysroots/cortexa35-ostl-linux if neither is set.
# ─────────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Resolve sysroot from env, fall back to the known default.
SYSROOT="${OECORE_TARGET_SYSROOT:-${SDKTARGETSYSROOT:-/opt/sdk/sysroots/cortexa35-ostl-linux}}"

# The cross-compiler to invoke. This must be on PATH (provided by SDK).
exec "${CROSS_COMPILE}gcc" --sysroot="$SYSROOT" "$@"
