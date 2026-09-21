# SPDX-License-Identifier: MIT

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
# Can be overridden on the command line (`make VAR=value`) or via environment variable.
OPTEE_CLIENT_EXPORT ?= /opt/sdk/sysroots/cortexa35-ostl-linux

# ── Build Target ───────────────────────────────────────────────────────────────
# Rust build target triple. Override on the command line or via environment variable.
TARGET ?= aarch64-unknown-linux-gnu

# ── Environment Variables ─────────────────────────────────────────────────────
# Defaults for cross-compilation and OP-TEE SDK paths.
# These allow lint/build to work even if .envrc hasn't been sourced.
CROSS_COMPILE ?= aarch64-ostl-linux-
OECORE_TARGET_SYSROOT ?= /opt/sdk/sysroots/cortexa35-ostl-linux
TA_DEV_KIT_DIR ?= /opt/sdk/sysroots/cortexa35-ostl-linux/usr/include/optee/export-user_ta_arm64

# ── Deploy target ──────────────────────────────────────────────────────────────
# The user for SSH/SCP deploy operations. Defaults to `current user for board access.
# Override with `make deploy DEPLOY_USER=otheruser`.
DEPLOY_USER ?= $(shell whoami)

# ── Host application ───────────────────────────────────────────────────────────
# Default name of the host application binary. Can be overridden on the command line
# (`make VAR=value`) or via environment variable.
HOST_APP ?= hello-world-host

# ── UUID ───────────────────────────────────────────────────────────────────────
# Path to the file containing the TA UUID. Can be overridden on the command line
# (`make VAR=value`) or via environment variable.
UUID ?= $(shell if [ -f ta/uuid.txt ]; then cat ta/uuid.txt; else echo "00000000-0000-0000-0000-000000000000"; fi)

# ── Cargo Verbose Flag ─────────────────────────────────────────────────────────
V ?=
CARGO_VERBOSE := $(if $(V),--verbose,)

.PHONY: all
all: ta host

.PHONY: init
init: check-uuid
	@echo "Initializing TA UUID..."
	uuidgen > ta/uuid.txt

# ── Build TA ───────────────────────────────────────────────────────────────────
# Builds the TA via cargo, strips the binary with objcopy, and signs it.
.PHONY: ta
ta: check-cargo check-uuid-file
	@echo "=== Building TA (UUID=$(UUID)) ==="
	@$(MAKE) copy-uuid
	TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
	cargo $(CARGO_VERBOSE) build \
		-p hello-world-ta \
		--target $(TARGET) \
		--release
	$(CROSS_COMPILE)objcopy --strip-unneeded \
		target/$(TARGET)/release/hello-world-ta \
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
	cp target/$(TARGET)/release/$(UUID).ta ta/ || exit 1

# ── Build Host ─────────────────────────────────────────────────────────────────
# Builds the host app via cargo and copies the binary to the host/ directory.
.PHONY: host
host: check-cargo copy-uuid
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
	cargo $(CARGO_VERBOSE) build \
		-p hello-world-host \
		--target $(TARGET) \
		--release
	cp target/$(TARGET)/release/hello-world-host host/ || exit 1

# ── Clean ─────────────────────────────────────────────────────────────────────
.PHONY: clean
clean: check-cargo
	cargo clean
	rm -f host/$(HOST_APP)
	rm -f ta/*.ta
	rm -f dyn_list

# ── Deploy ────────────────────────────────────────────────────────────────────
# Deploy the TA and host app to an STM32MP2 board running OP-TEE.
#
# Prerequisites:
#   - Board accessible via ssh/nfs or serial console
#   - OP-TEE OS running on the board
#   - TA binary copied to the board's TA store (e.g. /usr/lib/tee-datasync/)
#
# Usage: make deploy BOARD_ADDRESS=<board-address>
.PHONY: deploy
deploy:
	@if [ ! -f ta/$(UUID).ta ]; then \
		echo "ERROR: No TA binaries found. Run 'make ta' first."; \
		exit 1; \
	fi
	@if [ ! -f host/$(HOST_APP) ]; then \
		echo "ERROR: Host app binary not found. Run 'make host' first."; \
		exit 1; \
	fi
	@if [ -z "$(BOARD_ADDRESS)" ]; then \
		echo "Usage: make deploy BOARD_ADDRESS=<board-address>"; \
		exit 1; \
	fi
	@echo -e "=== Deploying artifacts to the board ($(BOARD_ADDRESS)) ===\n"
	scp ta/$(UUID).ta host/$(HOST_APP) $(DEPLOY_USER)@$(BOARD_ADDRESS):~
	@echo -e "=== Deployed. Run on board:\n"
	ssh $(DEPLOY_USER)@$(BOARD_ADDRESS) "sudo mv ~/$(UUID).ta /lib/optee_armtz/; sudo ./$(HOST_APP)"
	@echo -e "=== Verifying deployment ===\n"
	@if ! ssh $(DEPLOY_USER)@$(BOARD_ADDRESS) "test -f /lib/optee_armtz/$(UUID).ta && test -f ~/$(HOST_APP)"; then \
		echo "ERROR: Deployment verification failed on board."; \
		exit 1; \
	fi

# ── Format ────────────────────────────────────────────────────────────────────
.PHONY: format
format: check-cargo check-dprint
	dprint fmt
	cargo fmt

.PHONY: lint
lint: check-cargo check-dprint copy-uuid
	dprint check
	cargo fmt --check
	@echo "=== Linting TA (no_std) ==="
	# The TA is a cdylib with no binary targets, so --bins would cause cargo check
	# and cargo clippy to be a no-op. Omit --bins to lint the entire TA crate.
	TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
	cargo $(CARGO_VERBOSE) check -p hello-world-ta \
		--target $(TARGET) \
		--release
	cargo $(CARGO_VERBOSE) clippy -p hello-world-ta \
		--target $(TARGET) \
		--release \
		-- -D warnings
	@echo "=== Linting Host (std) ==="
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
	cargo $(CARGO_VERBOSE) clippy -p hello-world-host \
		--all-targets \
		--target $(TARGET) \
		--release \
		-- -D warnings

.PHONY: copy-uuid
copy-uuid:
	cp ta/uuid.txt host/uuid.txt || exit 1

.PHONY: check-dprint
check-dprint:
	@command -v dprint >/dev/null 2>&1 || (echo "dprint is not installed." && exit 1)

.PHONY: check-cargo
check-cargo:
	@command -v cargo >/dev/null 2>&1 || (echo "cargo is not installed." && exit 1)

.PHONY: check-uuid
check-uuid:
	@command -v uuidgen >/dev/null 2>&1 || (echo "uuidgen is not installed." && exit 1)

.PHONY: check-uuid-file
check-uuid-file:
	@test -f ta/uuid.txt || (echo "UUID file not found. Run 'make init' first." && exit 1)
