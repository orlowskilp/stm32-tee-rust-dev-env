# ── Host App Build ────────────────────────────────────────────────────────────
# Build the host application for ARM64.
#
# Variables required from parent:
#   CROSS_COMPILE - cross-compiler prefix (not used by host build; present for
#                   consistency with the TA build and future-proofing).
#   UUID          - TA UUID (passed from parent Makefile for consistency; not
#                   used by the host build itself).
#   TARGET        - cargo target triple (default: aarch64-unknown-linux-gnu)

# ── Verbose Output ─────────────────────────────────────────────────────────────
# V=1 enables verbose cargo output (e.g., make V=1).
CARGO_VERBOSE := $(if $(V),$(V),)

.PHONY: all host clean format lint

all: host

# ── Build Target ──────────────────────────────────────────────────────────────
TARGET ?= aarch64-unknown-linux-gnu

# Build the host application
host:
	@cargo build \
		--target $(TARGET) \
		--release

clean:
	@cargo clean


format:
	@cargo fmt

lint:
	@dprint check
	@cargo $(CARGO_VERBOSE) check --all-targets --target $(TARGET)
	@cargo fmt --check
	@cargo $(CARGO_VERBOSE) clippy --all-targets --target $(TARGET) -- -D warnings