# ── Environment Setup ──────────────────────────────────────────────────────────
#
# The container sets these via devcontainer.json or by sourcing .envrc which
# calls /opt/sdk/environment-setup:
#
#   TA_DEV_KIT_DIR     = /opt/sdk/sysroots/.../export-user_ta_arm64
#   CROSS_COMPILE      = aarch64-ostl-linux-
#   OPTEE_CLIENT_EXPORT= /opt/sdk/sysroots/cortexa35-ostl-linux
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

# ── Linker Wrapper ────────────────────────────────────────────────────────────
# Path to the cargo linker wrapper script that injects --sysroot.
LINKER_WRAPPER := $(abspath cargo-linker-wrapper.sh)

all: ta host

# ── Build TA ───────────────────────────────────────────────────────────────────
# Delegates to ta/Makefile with required variables.
ta:
	@$(MAKE) -C ta \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		TA_SIGN_KEY=$(TA_SIGN_KEY) \
		TA_SIGN_SCRIPT=$(TA_SIGN_SCRIPT) \
		LINKER_WRAPPER=$(LINKER_WRAPPER)

# ── Build Host ─────────────────────────────────────────────────────────────────
# Delegates to host/Makefile.
host:
	@$(MAKE) -C host LINKER_WRAPPER=$(LINKER_WRAPPER)

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	@$(MAKE) -C ta clean
	@$(MAKE) -C host clean

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
	@scp ta/target/aarch64-unknown-linux-gnu/release/$(shell cat ta/uuid.txt).ta root@$(BOARD_ADDRESS):/usr/lib/tee-datasync/
	@echo "=== Deploying host app ==="
	@scp host/target/aarch64-unknown-linux-gnu/release/hello_world_host root@$(BOARD_ADDRESS):/root/
	@echo "=== Deployed. Run on board:"
	@echo "  ssh $(shell whoami)@$(BOARD_ADDRESS) ./hello_world_host"

# ── Format ────────────────────────────────────────────────────────────────────
format: check-dprint
	dprint fmt

check-dprint:
	@command -v dprint >/dev/null 2>&1 || (echo "dprint is not installed. Please install it to build the project." && exit 1)

.PHONY: all ta host clean deploy format check-dprint
