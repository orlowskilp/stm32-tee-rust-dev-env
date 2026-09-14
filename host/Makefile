# ── Host App Build ────────────────────────────────────────────────────────────
# Build the host application for ARM64.
#
# Variables required from parent:
#   TARGET         - cargo target triple (default: aarch64-unknown-linux-gnu)

.PHONY: all host clean format lint

all: host

# ── Build Target ──────────────────────────────────────────────────────────────
TARGET ?= aarch64-unknown-linux-gnu

# Build the host application
host:
	@cargo build \
		--target $(TARGET) \
		--release \
		--config "target.$(TARGET).linker=\"$(LINKER_WRAPPER)\""

clean:
	@cargo clean


format:
	@cargo fmt

lint:
	@dprint check
	@cargo check --all-targets
	@cargo fmt --check
	@cargo clippy --all-targets -- -D warnings