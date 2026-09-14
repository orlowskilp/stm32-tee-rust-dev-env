# ── TA Build ───────────────────────────────────────────────────────────────────
# Build the Trusted Application for ARM64.
#
# Variables required from parent:
#   CROSS_COMPILE  - cross-compiler prefix (e.g. aarch64-ostl-linux-)
#   TA_SIGN_KEY    - path to TA signing key
#   TA_SIGN_SCRIPT - path to sign_encrypt.py

# ── TA UUID ────────────────────────────────────────────────────────────────────
UUID := $(shell cat uuid.txt)

.PHONY: all ta clean

all: ta

# Build the TA: cargo build → objcopy strip → sign
ta:
	@echo "=== Building TA (UUID=$(UUID)) ==="
	@CC=cc \
		RUSTC_LINKER=ld \
		cargo build \
			--target aarch64-unknown-linux-gnu \
			--release \
			--config "target.aarch64-unknown-linux-gnu.linker=\"$(LINKER_WRAPPER)\""
	@$(CROSS_COMPILE)objcopy --strip-unneeded \
		target/aarch64-unknown-linux-gnu/release/hello_world_ta \
		target/aarch64-unknown-linux-gnu/release/stripped_ta
	@if [ -n "$(TA_SIGN_KEY)" ] && [ -n "$(TA_SIGN_SCRIPT)" ]; then \
		python3 $(TA_SIGN_SCRIPT) --uuid $(UUID) --key $(TA_SIGN_KEY) \
			--in target/aarch64-unknown-linux-gnu/release/stripped_ta \
			--out target/aarch64-unknown-linux-gnu/release/$(UUID).ta; \
		echo "=== TA signed: target/aarch64-unknown-linux-gnu/release/$(UUID).ta ==="; \
	else \
		cp target/aarch64-unknown-linux-gnu/release/stripped_ta \
			target/aarch64-unknown-linux-gnu/release/$(UUID).ta; \
		echo "=== WARNING: TA signed (unsigned) ==="; \
		echo "Set TA_SIGN_KEY and TA_SIGN_SCRIPT to produce a signed TA."; \
	fi

clean:
	@cargo clean
