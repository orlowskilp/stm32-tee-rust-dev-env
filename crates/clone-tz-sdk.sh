#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

git clone https://github.com/apache/teaclave-trustzone-sdk.git "$SCRIPT_DIR/trustzone-sdk"
(cd "$SCRIPT_DIR/trustzone-sdk" && git checkout tags/v4.10.0 -b v4.10.0)