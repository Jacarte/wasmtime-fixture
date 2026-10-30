#!/bin/bash
set -uo pipefail
cd /testbed
export CARGO_NET_OFFLINE=true
python3 pepi_api_contract.py
