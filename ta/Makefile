# ── TA Build ───────────────────────────────────────────────────────────────────
# Build the Trusted Application for ARM64.
#
# Variables required from parent:
#   CROSS_COMPILE  - cross-compiler prefix (e.g. aarch64-ostl-linux-)
#   TA_SIGN_KEY    - path to TA signing key
#   TA_SIGN_SCRIPT - path to sign_encrypt.py
#   TARGET         - cargo target triple (default: aarch64-unknown-linux-gnu)

# ── TA UUID ────────────────────────────────────────────────────────────────────
UUID := $(shell cat uuid.txt)

# ── Build Target ──────────────────────────────────────────────────────────────
TARGET ?= aarch64-unknown-linux-gnu

.PHONY: all ta clean format lint

all: ta

# Build the TA: cargo build → objcopy strip → sign
ta:
	@echo "=== Building TA (UUID=$(UUID)) ==="
	@CC=cc \
		RUSTC_LINKER=ld \
		cargo build \
			--target $(TARGET) \
			--release \
			--config "target.$(TARGET).linker=\"$(LINKER_WRAPPER)\""
	@$(CROSS_COMPILE)objcopy --strip-unneeded \
		target/$(TARGET)/release/hello_world_ta \
		target/$(TARGET)/release/stripped_ta
	@if [ -n "$(TA_SIGN_KEY)" ] && [ -n "$(TA_SIGN_SCRIPT)" ]; then \
		python3 $(TA_SIGN_SCRIPT) --uuid $(UUID) --key $(TA_SIGN_KEY) \
			--in target/$(TARGET)/release/stripped_ta \
			--out target/$(TARGET)/release/$(UUID).ta; \
		echo "=== TA signed: target/$(TARGET)/release/$(UUID).ta ==="; \
	else \
		cp target/$(TARGET)/release/stripped_ta \
			target/$(TARGET)/release/$(UUID).ta; \
		echo "=== WARNING: TA signed (unsigned) ==="; \
		echo "Set TA_SIGN_KEY and TA_SIGN_SCRIPT to produce a signed TA."; \
	fi

clean:
	@cargo clean

format:
	@cargo fmt

lint:
	@dprint check
	@CC=cc \
		RUSTC_LINKER=ld \
		cargo check \
			--target $(TARGET) \
			--release \
			--bins \
			--config "target.$(TARGET).linker=\"$(LINKER_WRAPPER)\""
	@cargo fmt --check
	@CC=cc \
		RUSTC_LINKER=ld \
		cargo clippy \
			--target $(TARGET) \
			--release \
			--bins \
			--config "target.$(TARGET).linker=\"$(LINKER_WRAPPER)\"" \
			-- -D warnings