#!/usr/bin/env bash
set -euo pipefail

# Atom Oracle OP Stack follower template.
# This script intentionally requires local files and env vars; it does not embed secrets.

: "${OP_GETH_BIN:=op-geth}"
: "${OP_NODE_BIN:=op-node}"
: "${WORKDIR:=$PWD/opstack-follower}"
: "${CHAIN_ID:=20260619}"
: "${L1_RPC:?set L1_RPC to a Sepolia execution RPC URL}"
: "${L1_BEACON:?set L1_BEACON to a Sepolia beacon API URL}"
: "${NOVA_STATIC_PEER:?set NOVA_STATIC_PEER to /ip4/.../tcp/.../p2p/...}"
: "${L2_RPC_PORT:=8770}"
: "${L2_WS_PORT:=8771}"
: "${L2_AUTH_PORT:=8772}"
: "${L2_P2P_PORT:=30370}"
: "${OP_NODE_RPC_PORT:=9770}"
: "${OP_NODE_P2P_PORT:=9771}"

GENESIS_JSON="${GENESIS_JSON:-$WORKDIR/genesis.json}"
ROLLUP_JSON="${ROLLUP_JSON:-$WORKDIR/rollup.json}"
JWT_FILE="${JWT_FILE:-$WORKDIR/jwt.txt}"
GETH_DATADIR="${GETH_DATADIR:-$WORKDIR/geth-data}"
OPNODE_DATADIR="${OPNODE_DATADIR:-$WORKDIR/opnode-data}"

if [[ ! -s "$GENESIS_JSON" ]]; then
  echo "missing genesis.json: $GENESIS_JSON" >&2
  exit 1
fi
if [[ ! -s "$ROLLUP_JSON" ]]; then
  echo "missing rollup.json: $ROLLUP_JSON" >&2
  exit 1
fi
if [[ ! -s "$JWT_FILE" ]]; then
  echo "missing jwt.txt: $JWT_FILE" >&2
  exit 1
fi

mkdir -p "$GETH_DATADIR" "$OPNODE_DATADIR"

if [[ ! -d "$GETH_DATADIR/geth" ]]; then
  "$OP_GETH_BIN" init --datadir "$GETH_DATADIR" "$GENESIS_JSON"
fi

"$OP_GETH_BIN" \
  --datadir "$GETH_DATADIR" \
  --networkid "$CHAIN_ID" \
  --http --http.addr 0.0.0.0 --http.port "$L2_RPC_PORT" \
  --http.api eth,net,web3,debug,engine \
  --http.corsdomain '*' --http.vhosts '*' \
  --ws --ws.addr 0.0.0.0 --ws.port "$L2_WS_PORT" --ws.origins '*' \
  --authrpc.addr 127.0.0.1 --authrpc.port "$L2_AUTH_PORT" \
  --authrpc.vhosts '*' --authrpc.jwtsecret "$JWT_FILE" \
  --syncmode full --gcmode archive \
  --rollup.disabletxpoolgossip=true \
  --port "$L2_P2P_PORT" \
  --nodiscover \
  > "$WORKDIR/op-geth.log" 2>&1 &
GETH_PID=$!

echo "started op-geth pid=$GETH_PID rpc=$L2_RPC_PORT auth=$L2_AUTH_PORT"
sleep 3

exec "$OP_NODE_BIN" \
  --l1 "$L1_RPC" \
  --l1.beacon "$L1_BEACON" \
  --l1.rpckind standard \
  --l2 "http://127.0.0.1:$L2_AUTH_PORT" \
  --l2.jwt-secret "$JWT_FILE" \
  --l2.enginekind geth \
  --rollup.config "$ROLLUP_JSON" \
  --rpc.addr 0.0.0.0 --rpc.port "$OP_NODE_RPC_PORT" \
  --p2p.listen.tcp "$OP_NODE_P2P_PORT" \
  --p2p.listen.udp "$OP_NODE_P2P_PORT" \
  --p2p.static "$NOVA_STATIC_PEER" \
  --syncmode consensus-layer \
  --syncmode.req-resp
