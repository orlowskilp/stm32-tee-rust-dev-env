# ── Host App Build ────────────────────────────────────────────────────────────
# Build the host application for ARM64.
#
# No special variables required from parent.

.PHONY: all host clean format lint

all: host

# Build the host application
host:
	@cargo build \
		--target aarch64-unknown-linux-gnu \
		--release \
		--config "target.aarch64-unknown-linux-gnu.linker=\"$(LINKER_WRAPPER)\""

clean:
	@cargo clean


format:
	@cargo fmt

lint:
	@dprint check
	@cargo check --all-targets
	@cargo fmt --check
	@cargo clippy --all-targets -- -D warnings