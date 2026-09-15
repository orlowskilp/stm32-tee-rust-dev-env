#!/bin/bash

sudo chown -R $(whoami):$(whoami) ~/.local

# Install Rust toolchains declared in rust-toolchain
rustup toolchain install
