CROSS_COMPILE ?= aarch64-linux-gnu-

# TA signing key — must match the key used to build OP-TEE on your board.
# Generated during optee_os build (ta_sign_key.pem or similar).
# If using the Yocto SDK default:
TA_SIGN_KEY ?= $(shell find /opt/sdk/sysroots -name "ta_sign_key.pem" -type f 2>/dev/null | head -1)

# OP-TEE signing script from optee_os (used to sign encrypted TA binaries).
TA_SIGN_SCRIPT ?= $(shell find /workspace -name "sign_encrypt.py" -type f 2>/dev/null | head -1)

# UUID of the hello_world TA — must match uuid.txt in ta/.
UUID := $(shell cat ta/uuid.txt)

# Build the Trusted Application (TA) for ARM64.
# Steps: cargo build → objcopy strip → sign_encrypt.py
#
# Prerequisites:
#   - trustzone-sdk submodule under crates/ must be initialized
#   - TA_DEV_KIT_DIR set from the SDK environment (source .envrc)
#   - TA_SIGN_KEY must point to the TA signing private key
#   - TA_SIGN_SCRIPT must point to optee_os's sign_encrypt.py
#
# Usage: make ta [TA_SIGN_KEY=key.pem]
ta:
	@echo "=== Building TA (UUID=$(UUID)) ==="
	cd ta && cargo build \
		--target aarch64-unknown-linux-gnu \
		--release \
		--config target.aarch64-unknown-linux-gnu.linker="$(CROSS_COMPILE)gcc"
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

# Build the host application for ARM64.
# Links against libteec.so from the optee_client export.
#
# Prerequisites:
#   - trustzone-sdk submodule under crates/ must be initialized
#   - OPTEE_CLIENT_EXPORT set from the SDK environment
#
# Usage: make host
host:
	cd host_app && cargo build \
		--target aarch64-unknown-linux-gnu \
		--release \
		--config target.aarch64-unknown-linux-gnu.linker="$(CROSS_COMPILE)gcc" \
		-C link-arg=-lteec

# Clean all build artifacts.
clean:
	cd ta && cargo clean
	cd host_app && cargo clean

# Deploy the TA and host app to an STM32MP2 board running OP-TEE.
#
# Prerequisites:
#   - Board accessible via ssh/nfs or serial console
#   - OP-TEE OS running on the board
#   - TA binary copied to the board's TA store (e.g. /usr/lib/tee-datasync/)
#
# Usage: make deploy BOARD_IP=<board-ip>
deploy:
	@if [ -z "$(BOARD_IP)" ]; then \
		echo "Usage: make deploy BOARD_IP=<board-ip>"; \
		exit 1; \
	fi
	@echo "=== Deploying TA ==="
	scp ta/target/aarch64-unknown-linux-gnu/release/$(UUID).ta root@$(BOARD_IP):/usr/lib/tee-datasync/
	@echo "=== Deploying host app ==="
	scp host_app/target/aarch64-unknown-linux-gnu/release/hello_world_host root@$(BOARD_IP):/root/
	@echo "=== Deployed. Run on board:"
	@echo "  ssh root@$(BOARD_IP) ./hello_world_host"

# Format codebase
format: check-dprint
		dprint fmt

# Check dprint
check-dprint:
		@command -v dprint >/dev/null 2>&1 || (echo "dprint is not installed. Please install it to build the project." && exit 1)

.PHONY: ta host clean deploy format check-cargo check-dprint
