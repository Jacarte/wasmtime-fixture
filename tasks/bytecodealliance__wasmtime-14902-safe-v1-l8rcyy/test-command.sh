#!/bin/bash
set -uo pipefail
cd /testbed
export CARGO_NET_OFFLINE=true
cargo build --locked --offline --bin wasmtime || exit $?
python3 pepi_cli_contract.py
