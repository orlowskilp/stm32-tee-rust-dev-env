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

# ── OP-TEE Client SDK ────────────────────────────────────────────────────────
# Path to the OP-TEE client export directory (contains libteec.so and headers).
# Override with -e to use a different path.
OPTEE_CLIENT_EXPORT ?= /opt/sdk/sysroots/cortexa35-ostl-linux

# ── Build Target ───────────────────────────────────────────────────────────────
# Cross-compilation target for STM32MP2. Override with -e or env var to target
# a different platform.
TARGET ?= aarch64-unknown-linux-gnu

# ── Environment Variables ─────────────────────────────────────────────────────
# Defaults for cross-compilation and OP-TEE SDK paths.
# These allow lint/build to work even if .envrc hasn't been sourced.
CROSS_COMPILE ?= aarch64-ostl-linux-
OECORE_TARGET_SYSROOT ?= /opt/sdk/sysroots/cortexa35-ostl-linux
TA_DEV_KIT_DIR ?= /opt/sdk/sysroots/cortexa35-ostl-linux/usr/include/optee/export-user_ta_arm64

# ── User ─────────────────────────────────────────────────────────────────────
# The user running the make commands. Defaults to the current system user.
USER ?= $(shell whoami)

# ── Host application ───────────────────────────────────────────────────────────
# Name of the host application binary. Can be overridden with -e or env var.
HOST_APP ?= hello-world-host

.PHONY: all ta init host clean deploy format lint check-dprint check-cargo copy-uuid

all: ta host

init: check-uuid
	@echo "Initializing TA UUID..."
	@uuidgen > ta/uuid.txt

# ── Build TA ───────────────────────────────────────────────────────────────────
# Delegates to ta/Makefile with required variables.
ta: check-cargo
	@$(MAKE) -C ta \
		UUID=$$(cat ta/uuid.txt) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		TA_SIGN_KEY=$(TA_SIGN_KEY) \
		TA_SIGN_SCRIPT=$(TA_SIGN_SCRIPT) \
		TARGET=$(TARGET)

# ── Build Host ─────────────────────────────────────────────────────────────────
# Delegates to host/Makefile.
host: check-cargo copy-uuid
	@$(MAKE) -C host \
		UUID=$$(cat ta/uuid.txt) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
		TARGET=$(TARGET)

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
	@if ! ls ta/target/$(TARGET)/release/*.ta >/dev/null 2>&1; then \
		echo "ERROR: No TA binaries found. Run 'make ta' first."; \
		exit 1; \
	fi
	@if [ ! -f host/target/$(TARGET)/release/$(HOST_APP) ]; then \
		echo "ERROR: Host app binary not found. Run 'make host' first."; \
		exit 1; \
	fi
	@if [ -z "$(BOARD_ADDRESS)" ]; then \
		echo "Usage: make deploy BOARD_ADDRESS=<board-address>"; \
		exit 1; \
	fi
	@echo -e "=== Deploying artifacts to the board ($(BOARD_ADDRESS)) ===\n"
	scp ta/target/$(TARGET)/release/$$(cat ta/uuid.txt).ta host/target/$(TARGET)/release/$(HOST_APP) $(USER)@$(BOARD_ADDRESS):~
	@echo -e "=== Deployed. Run on board:\n"
	ssh $(USER)@$(BOARD_ADDRESS) "sudo mv ~/$$(cat ta/uuid.txt).ta /lib/optee_armtz/; sudo ./$(HOST_APP)"
	@echo -e "=== Verifying deployment ===\n"
	@if ! ssh $(USER)@$(BOARD_ADDRESS) "test -f /lib/optee_armtz/$$(cat ta/uuid.txt).ta && test -f ~/$(HOST_APP)"; then \
		echo "ERROR: Deployment verification failed on board."; \
		exit 1; \
	fi

# ── Format ────────────────────────────────────────────────────────────────────
format: check-cargo check-dprint
	@dprint fmt
	@$(MAKE) -C ta format
	@$(MAKE) -C host format

lint: check-cargo check-dprint copy-uuid
	@$(MAKE) -C ta lint \
		UUID=$$(cat ta/uuid.txt) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		TA_SIGN_KEY=$(TA_SIGN_KEY) \
		TA_SIGN_SCRIPT=$(TA_SIGN_SCRIPT) \
		TARGET=$(TARGET)
	@$(MAKE) -C host lint \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
		UUID=$$(cat ta/uuid.txt) \
		TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
		TARGET=$(TARGET)

copy-uuid:
	@cp ta/uuid.txt host/uuid.txt || exit 1

check-dprint:
	@command -v dprint >/dev/null 2>&1 || (echo "dprint is not installed." && exit 1)

check-cargo:
	@command -v cargo >/dev/null 2>&1 || (echo "cargo is not installed." && exit 1)

check-uuid:
	@command -v uuidgen >/dev/null 2>&1 || (echo "uuidgen is not installed." && exit 1)