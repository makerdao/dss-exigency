#!/usr/bin/env bash
set -e

[[ "$ETH_RPC_URL" && "$(seth chain)" == "ethlive" ]] || { echo "Please set a mainnet ETH_RPC_URL"; exit 1; }

export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=1

if [[ -z "$1" ]]; then
  dapp --use solc:0.5.12 test --rpc-url="$ETH_RPC_URL" --verbose 1 --match='testDEFCON[1-5]'
else
  dapp --use solc:0.5.12 test --rpc-url="$ETH_RPC_URL" --match "$1" -vv
fi
