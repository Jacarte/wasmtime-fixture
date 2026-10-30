#!/bin/bash
set -uo pipefail
cd /testbed
export CARGO_NET_OFFLINE=true
cargo test --locked --offline -p wasmtime-wasi-http --test all p3::p3_http_forward_body:: -- --test-threads=1
a=$?
cargo test --locked --offline -p wasmtime-wasi-http --test all p3::p3_http_echo -- --exact --test-threads=1
b=$?
exit $((a || b))
