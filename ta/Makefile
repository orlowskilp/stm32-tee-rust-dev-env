# Build the OP-TEE Trusted Application: cargo build → objcopy strip → sign.
#
# ── Verbosity ─────────────────────────────────────────────────────────────────
# Controls verbose output from cargo commands. When set to any non-empty value
# (e.g., `make V=1`), cargo commands emit full build logs.
V ?=
CARGO_VERBOSE := $(if $(V),--verbose,)
#
# ── Target Triple ─────────────────────────────────────────────────────────────
# Rust target triple for the cross-compiled TA binary. Passed from the root
# Makefile by default; can be overridden via environment or command line.
TARGET ?= aarch64-unknown-linux-gnu
#
# ── TA UUID ───────────────────────────────────────────────────────────────────
# UUID for the Trusted Application, used as the output filename for the signed
# binary (e.g., `<UUID>.ta`). Read from uuid.txt by default if available.
UUID ?= $(shell cat uuid.txt 2>/dev/null || echo 00000000-0000-0000-0000-000000000000)
#
# ── Package Name ──────────────────────────────────────────────────────────────
# Binary name extracted from `cargo pkgid`, used as input to objcopy for
# stripping before signing. Auto-computed; do not override.
PKG_NAME := $(shell cargo pkgid | awk -F '#'  '{ print $$2 }' | awk -F '@' '{ print $$1 }')
#
# ── Cross-Compiler Prefix ─────────────────────────────────────────────────────
# Prefix for cross-compilation tools (objcopy, etc.), e.g. `aarch64-ostl-linux-`.
# Passed from the root Makefile.
CROSS_COMPILE ?=
#
# ── Signing Key ───────────────────────────────────────────────────────────────
# Path to the RSA private key used to sign the TA binary. Required when building
# a signed TA; omitted for testing without signatures.
TA_SIGN_KEY ?=
#
# ── Signing Script ─────────────────────────────────────────────────────────────
# Path to the Python signing script (e.g., sign_encrypt.py). Used alongside
# TA_SIGN_KEY to produce the final signed `.ta` binary.
TA_SIGN_SCRIPT ?=
#
# Override any variable on the command line with `make -C ta VAR=value`.

.PHONY: all
all: $(UUID).ta

# Build the TA: cargo build → objcopy strip → sign
$(UUID).ta: check-uuid-file
	@echo "=== Building TA (UUID=$(UUID)) ==="
	cargo $(CARGO_VERBOSE) build \
		--target $(TARGET) \
		--release
	$(CROSS_COMPILE)objcopy --strip-unneeded \
		target/$(TARGET)/release/$(PKG_NAME) \
		target/$(TARGET)/release/stripped_ta
	@if [ -n "$(TA_SIGN_KEY)" ] && [ -n "$(TA_SIGN_SCRIPT)" ]; then \
		python3 $(TA_SIGN_SCRIPT) --uuid $(UUID) --key $(TA_SIGN_KEY) \
			--in target/$(TARGET)/release/stripped_ta \
			--out target/$(TARGET)/release/$(UUID).ta; \
		echo "=== TA signed: target/$(TARGET)/release/$(UUID).ta ==="; \
	else \
		echo "=== ERROR: Cannot build signed TA — set TA_SIGN_KEY and TA_SIGN_SCRIPT ===" >&2; \
		exit 1; \
	fi
	cp target/$(TARGET)/release/$(UUID).ta . || exit 1

.PHONY: clean
clean:
	cargo clean
	rm -f $(UUID).ta

.PHONY: format
format:
	cargo fmt

.PHONY: lint
lint:
	dprint check
	cargo $(CARGO_VERBOSE) check \
		--target $(TARGET) \
		--release \
		--bins
	cargo fmt --check
	cargo $(CARGO_VERBOSE) clippy \
		--target $(TARGET) \
		--release \
		--bins \
		-- -D warnings

.PHONY: check-uuid-file
check-uuid-file:
	@test -f uuid.txt || (echo "UUID file not found." && exit 1)