# Verbose cargo output when V=1 is passed (e.g., `make V=1`).
CARGO_VERBOSE := $(if $(V),--verbose,)

# ── Build Target ──────────────────────────────────────────────────────────────
TARGET ?= aarch64-unknown-linux-gnu

UUID ?= $(shell cat uuid.txt 2>/dev/null || echo 00000000-0000-0000-0000-000000000000)

# ── Package Name ──────────────────────────────────────────────────────────────
PKG_NAME := $(shell cargo pkgid | awk -F '#'  '{ print $$2 }' | awk -F '@' '{ print $$1 }')

.PHONY: all
all: $(UUID).ta

# Build the TA: cargo build → objcopy strip → sign
$(UUID).ta: check-uuid-file
	@echo "=== Building TA (UUID=$(UUID)) ==="
	cargo $(CARGO_VERBOSE) build \
		--target $(TARGET) \
		--release
	$(CROSS_COMPILE)objcopy --strip-unneeded \
		target/$(TARGET)/release/$(PKG_NAME) \
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
	cp target/$(TARGET)/release/$(UUID).ta . || exit 1

.PHONY: clean
clean:
	cargo clean
	rm -f $(UUID).ta

.PHONY: format
format:
	cargo fmt

.PHONY: lint
lint:
	dprint check
	cargo $(CARGO_VERBOSE) check \
		--target $(TARGET) \
		--release \
		--bins
	cargo fmt --check
	cargo $(CARGO_VERBOSE) clippy \
		--target $(TARGET) \
		--release \
		--bins \
		-- -D warnings

.PHONY: check-uuid-file
check-uuid-file:
	@test -f uuid.txt || (echo "UUID file not found." && exit 1)