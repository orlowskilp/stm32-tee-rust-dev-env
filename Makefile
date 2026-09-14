# ── Environment Setup ──────────────────────────────────────────────────────────
#
# The container sets these via devcontainer.json or by sourcing .envrc which
# calls /opt/sdk/environment-setup:
#
#   TA_DEV_KIT_DIR     = /opt/sdk/sysroots/.../export-user_ta_arm64
#   CROSS_COMPILE      = aarch64-ostl-linux-
#   OPTEE_CLIENT_EXPORT= /opt/sdk/sysroots/cortexa35-ostl-linux/usr
#   OECORE_TARGET_SYSROOT = /opt/sdk/sysroots/cortexa35-ostl-linux
#
# Override any of these by setting them before invoking make.

# ── OP-TEE Signing ─────────────────────────────────────────────────────────────
#
# Default test key shipped by the SDK. Suitable for development only — it is
# NOT bound to your board's OP-TEE instance. Use this to develop and test
# before switching to the board-specific key (see QUICKSTART.md).
TA_SIGN_KEY ?= $(TA_DEV_KIT_DIR)/keys/default_ta.pem

# sign_encrypt.py lives inside the TA dev kit export.
TA_SIGN_SCRIPT ?= $(TA_DEV_KIT_DIR)/scripts/sign_encrypt.py

# ── TA UUID ───────────────────────────────────────────────────────────────────
UUID := $(shell cat ta/uuid.txt)

# ── Build the Trusted Application (TA) for ARM64 ──────────────────────────────
#
# Steps: cargo build → objcopy strip → sign_encrypt.py
#
# Prerequisites:
#   - trustzone-sdk submodule under crates/ must be initialized
#   - TA_DEV_KIT_DIR set (exported by devcontainer.json / .envrc)
#   - TA_SIGN_KEY must point to the TA signing private key
#   - TA_SIGN_SCRIPT must point to optee_os's sign_encrypt.py
#
# Usage: make ta [TA_SIGN_KEY=key.pem]
ta:
	@echo "=== Building TA (UUID=$(UUID)) ==="
	cd ta && cargo build \
		--target aarch64-unknown-linux-gnu \
		--release \
		--config "target.aarch64-unknown-linux-gnu.linker=\"$(PWD)/cargo-linker-wrapper.sh\""
	objcopy --strip-unneeded ta/target/aarch64-unknown-linux-gnu/release/hello_world_ta \
		ta/target/aarch64-unknown-linux-gnu/release/stripped_ta
	@if [ -n "$(TA_SIGN_KEY)" ] && [ -n "$(TA_SIGN_SCRIPT)" ]; then \
		python3 $(TA_SIGN_SCRIPT) --uuid $(UUID) --key $(TA_SIGN_KEY) \
			--in ta/target/aarch64-unknown-linux-gnu/release/stripped_ta \
			--out ta/target/aarch64-unknown-linux-gnu/release/$(UUID).ta; \
		echo "=== TA signed: ta/target/aarch64-unknown-linux-gnu/release/$(UUID).ta ==="; \
	else \
		cp ta/target/aarch64-unknown-linux-gnu/release/stripped_ta \
			ta/target/aarch64-unknown-linux-gnu/release/$(UUID).ta; \
		echo "=== WARNING: TA signed (unsigned) ==="; \
		echo "Set TA_SIGN_KEY and TA_SIGN_SCRIPT in the Makefile to produce a signed TA."; \
	fi

# ── Build the host application for ARM64 ──────────────────────────────────────
#
# Links against libteec.so from the optee_client export.
#
# Prerequisites:
#   - trustzone-sdk submodule under crates/ must be initialized
#   - OPTEE_CLIENT_EXPORT set from the SDK environment
#
# Usage: make host
host:
	cd host_app && \
		cargo build \
			--target aarch64-unknown-linux-gnu \
			--release \
			--config "target.aarch64-unknown-linux-gnu.linker=\"$(PWD)/cargo-linker-wrapper.sh\""

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	cd ta && cargo clean
	cd host_app && cargo clean

# ── Deploy ────────────────────────────────────────────────────────────────────
# Deploy the TA and host app to an STM32MP2 board running OP-TEE.
#
# Prerequisites:
#   - Board accessible via ssh/nfs or serial console
#   - OP-TEE OS running on the board
#   - TA binary copied to the board's TA store (e.g. /usr/lib/tee-datasync/)
#
# Usage: make deploy BOARD_ADDRESS=<board-address>
deploy:
	@if [ -z "$(BOARD_ADDRESS)" ]; then \
		echo "Usage: make deploy BOARD_ADDRESS=<board-address>"; \
		exit 1; \
	fi
	@echo "=== Deploying TA ==="
	scp ta/target/aarch64-unknown-linux-gnu/release/$(UUID).ta root@$(BOARD_ADDRESS):/usr/lib/tee-datasync/
	@echo "=== Deploying host app ==="
	scp host_app/target/aarch64-unknown-linux-gnu/release/hello_world_host root@$(BOARD_ADDRESS):/root/
	@echo "=== Deployed. Run on board:"
	@echo "  ssh root@$(BOARD_ADDRESS) ./hello_world_host"

# ── Format ────────────────────────────────────────────────────────────────────
format: check-dprint
	dprint fmt

check-dprint:
	@command -v dprint >/dev/null 2>&1 || (echo "dprint is not installed. Please install it to build the project." && exit 1)

.PHONY: ta host clean deploy format check-cargo check-dprint
