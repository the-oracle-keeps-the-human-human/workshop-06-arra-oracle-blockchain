#!/usr/bin/env bash
set -euo pipefail
: "${L2_RPC_PORT:=8770}"
: "${OP_NODE_RPC_PORT:=9770}"

rpc() {
  local port="$1" method="$2"
  curl -fsS "http://127.0.0.1:${port}" \
    -H 'content-type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"${method}\",\"params\":[]}"
}

echo "== execution layer =="
rpc "$L2_RPC_PORT" eth_chainId; echo
rpc "$L2_RPC_PORT" eth_blockNumber; echo

echo "== op-node =="
rpc "$OP_NODE_RPC_PORT" optimism_syncStatus; echo
