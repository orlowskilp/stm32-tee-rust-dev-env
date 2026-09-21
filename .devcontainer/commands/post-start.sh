#!/bin/bash

# SPDX-License-Identifier: MIT

# Enforce ownership of local user files
sudo chown -R $(whoami):$(whoami) ~/.local

# Install the default Rust toolchain
rustup toolchain install stable nightly