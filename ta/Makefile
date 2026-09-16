# ── TA Build ───────────────────────────────────────────────────────────────────
# Build the Trusted Application for ARM64.
#
# Variables required from parent:
#   CROSS_COMPILE  - cross-compiler prefix (e.g. aarch64-ostl-linux-), only for `build`
#   TA_SIGN_KEY    - path to TA signing key
#   TA_SIGN_SCRIPT - path to sign_encrypt.py
#   TARGET         - cargo target triple (default: aarch64-unknown-linux-gnu)
#   UUID           - TA UUID (passed from parent Makefile)
#
# UUID is passed from the parent Makefile at execution time.
# The parent reads uuid.txt via $$(cat ta/uuid.txt) in recipe lines so that
# the file is read only after make init has created it.

# ── Verbose Output ─────────────────────────────────────────────────────────────
# V=1 enables verbose cargo output (e.g., make V=1).
CARGO_VERBOSE := $(if $(V),$(V),)

# ── Build Target ──────────────────────────────────────────────────────────────
TARGET ?= aarch64-unknown-linux-gnu

# ── Package Name ──────────────────────────────────────────────────────────────
PKG_NAME := hello-world-ta

.PHONY: all ta clean format lint

all: ta

# Build the TA: cargo build → objcopy strip → sign
ta:
	@echo "=== Building TA (UUID=$(UUID)) ==="
	@CC=cc \
		RUSTC_LINKER=ld \
		cargo $(CARGO_VERBOSE) build \
			--target $(TARGET) \
			--release
	@$(CROSS_COMPILE)objcopy --strip-unneeded \
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

clean:
	@cargo clean
	@$(RM) target/$(TARGET)/release/stripped_ta target/$(TARGET)/release/*.ta

format:
	@cargo fmt

lint:
	@dprint check
	@cargo $(CARGO_VERBOSE) check \
		--target $(TARGET) \
		--release \
		--bins
	@cargo fmt --check
	@cargo $(CARGO_VERBOSE) clippy \
		--target $(TARGET) \
		--release \
		--bins \
		-- -D warnings