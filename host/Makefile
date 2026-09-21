# SPDX-License-Identifier: MIT
#
# Build the host application for OP-TEE integration (cargo build).
#
# ── Verbosity ─────────────────────────────────────────────────────────────────
# Controls verbose output from cargo commands. When set to any non-empty value
# (e.g., `make V=1`), cargo commands emit full build logs.
V ?=
CARGO_VERBOSE := $(if $(V),--verbose,)
#
# ── Host Application Name ─────────────────────────────────────────────────────
# Binary name extracted from `cargo pkgid`, used as the output filename.
# Auto-computed; do not override.
HOST_APP := $(shell cargo pkgid | awk -F '#'  '{ print $$2 }' | awk -F '@' '{ print $$1 }')
#
# ── Target Triple ─────────────────────────────────────────────────────────────
# Rust target triple for the cross-compiled host binary. Passed from the root
# Makefile by default; can be overridden via environment or command line.
TARGET ?= aarch64-unknown-linux-gnu
#
# ── Cross-Compiler Prefix ─────────────────────────────────────────────────────
# Prefix for cross-compilation tools (objcopy, etc.), e.g. `aarch64-ostl-linux-`.
# Passed from the root Makefile.
CROSS_COMPILE ?=
#
# ── OP-TEE Client SDK ─────────────────────────────────────────────────────────
# Path to the OP-TEE client SDK export directory containing libteec.so and
# header files. Required for host apps that link against the OP-TEE client.
OPTEE_CLIENT_EXPORT ?=
#
# ── TA UUID ───────────────────────────────────────────────────────────────────
# UUID of the paired Trusted Application. Copied from ta/uuid.txt by the root
# Makefile; used by check-uuid-file to ensure uuid.txt exists.
UUID ?=
#
# ── TA Dev Kit Directory ──────────────────────────────────────────────────────
# Path to the OP-TEE TA development kit. Used during linting to ensure the
# correct cross-compilation environment is available (passed via `make lint`).
TA_DEV_KIT_DIR ?=
#
# Override any variable on the command line with `make -C host VAR=value`.

.PHONY: all
all: $(HOST_APP)

# Build the host application binary and copy it to the Makefile directory.
$(HOST_APP): check-uuid-file
	cargo build \
		--target $(TARGET) \
		--release
	cp target/$(TARGET)/release/$(HOST_APP) . || exit 1

# Clean build artifacts.
.PHONY: clean
clean:
	cargo clean
	rm -f $(HOST_APP)

# Format Rust source code.
.PHONY: format
format:
	cargo fmt

# Lint Rust source code with clippy, cargo fmt, and dprint.
.PHONY: lint
lint:
	dprint check
	cargo $(CARGO_VERBOSE) check --all-targets --target $(TARGET)
	cargo fmt --check
	cargo $(CARGO_VERBOSE) clippy --all-targets --target $(TARGET) -- -D warnings

# 
.PHONY: check-uuid-file
check-uuid-file:
	@test -f uuid.txt || (echo "UUID file not found." && exit 1)