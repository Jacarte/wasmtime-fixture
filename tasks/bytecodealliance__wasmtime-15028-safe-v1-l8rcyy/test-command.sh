#!/bin/bash
set -uo pipefail
cd /testbed
export CARGO_NET_OFFLINE=true
cargo test --locked --offline --test all --features component-model-async cli_serve_trap_mid_body -- --test-threads=1
a=$?
cargo test --locked --offline --test all --features component-model-async cli_tests::test_programs::p2_cli_serve_hello_world -- --exact --test-threads=1
b=$?
cargo test --locked --offline --test all --features component-model-async cli_tests::test_programs::p3_cli_serve_hello_world -- --exact --test-threads=1
c=$?
exit $((a || b || c))
