#!/bin/bash
set -uo pipefail
cd /testbed
export CARGO_NET_OFFLINE=true
cargo test --locked --offline -p wasmtime-wast --features component-model,component-model-async,wasmtime/default --test pepi_safe -- --test-threads=1
