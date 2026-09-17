# Verbose cargo output when V=1 is passed (e.g., `make V=1`).
CARGO_VERBOSE := $(if $(V),$(V),)

# ── Host Application Name ─────────────────────────────────────────────────────
# Extract the host application name from the Cargo package ID.
HOST_APP := $(shell cargo pkgid | awk -F '#'  '{ print $$2 }' | awk -F '@' '{ print $$1 }')

# ── Build Target ──────────────────────────────────────────────────────────────
# Provided by the parent Makefile or environment, otherwise defaults are used.
TARGET ?= aarch64-unknown-linux-gnu

.PHONY: all
all: $(HOST_APP)

# Build the host application binary and copy it to the Makefile directory.
$(HOST_APP): check-uuid-file
	cargo build \
		--target $(TARGET) \
		--release
	cp target/$(TARGET)/release/$(HOST_APP) . || exit 1

# Clean build artifacts.
.PHONY: clean
clean:
	cargo clean
	rm -f $(HOST_APP)

# Format Rust source code.
.PHONY: format
format:
	cargo fmt

# Lint Rust source code with clippy, cargo fmt, and dprint.
.PHONY: lint
lint:
	dprint check
	cargo $(CARGO_VERBOSE) check --all-targets --target $(TARGET)
	cargo fmt --check
	cargo $(CARGO_VERBOSE) clippy --all-targets --target $(TARGET) -- -D warnings

# 
.PHONY: check-uuid-file
check-uuid-file:
	@test -f uuid.txt || (echo "UUID file not found." && exit 1)