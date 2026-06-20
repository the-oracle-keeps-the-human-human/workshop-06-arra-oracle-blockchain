#!/usr/bin/env bash
# Vessel Oracle — Sync to OP Stack L2 (Chain ID: 20260619)
# Requires: docker, L1_RPC_URL, L1_BEACON_URL, rollup.json, jwt.txt
# Usage: L1_RPC_URL=https://... L1_BEACON_URL=https://... bash sync-opstack.sh

set -e

CHAIN_ID=20260619
DATADIR="$HOME/.vessel-opstack-${CHAIN_ID}"
L1_RPC_URL="${L1_RPC_URL:?need L1_RPC_URL (Sepolia RPC)}"
L1_BEACON_URL="${L1_BEACON_URL:?need L1_BEACON_URL (Sepolia beacon)}"
ROLLUP_JSON="${ROLLUP_JSON:-./vessel/rollup.json}"
JWT_SECRET="${JWT_SECRET:-./vessel/jwt.txt}"

mkdir -p "$DATADIR/geth-data"

# Generate JWT if missing
if [ ! -f "$JWT_SECRET" ]; then
  openssl rand -hex 32 > "$JWT_SECRET"
  echo "Generated JWT: $JWT_SECRET"
fi

echo "==> Step 1: Init op-geth with L2 genesis"
docker run --rm \
  -v "$DATADIR/geth-data:/data" \
  -v "$(realpath "$ROLLUP_JSON"):/rollup.json" \
  us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:v1.101511.1 \
  init --datadir=/data /rollup.json 2>/dev/null || true

echo "==> Step 2: Start op-geth (execution layer)"
docker run -d \
  --name vessel-op-geth-${CHAIN_ID} \
  -v "$DATADIR/geth-data:/data" \
  -v "$(realpath "$JWT_SECRET"):/jwt.txt" \
  -p 8545:8545 \
  -p 8546:8546 \
  -p 18551:8551 \
  us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:v1.101511.1 \
  --datadir=/data \
  --http --http.addr=0.0.0.0 --http.port=8545 \
  --http.api=eth,net,web3,debug,txpool \
  --http.vhosts=* --http.corsdomain=* \
  --ws --ws.addr=0.0.0.0 --ws.port=8546 \
  --ws.api=eth,net,web3 --ws.origins=* \
  --authrpc.addr=0.0.0.0 --authrpc.port=8551 \
  --authrpc.jwtsecret=/jwt.txt \
  --authrpc.vhosts=* \
  --syncmode=full --gcmode=archive \
  --rollup.disabletxpoolgossip=true

echo "==> Step 3: Start op-node (rollup consensus — derives L2 from Sepolia L1)"
docker run -d \
  --name vessel-op-node-${CHAIN_ID} \
  --link vessel-op-geth-${CHAIN_ID}:op-geth \
  -v "$(realpath "$ROLLUP_JSON"):/rollup.json" \
  -v "$(realpath "$JWT_SECRET"):/jwt.txt" \
  -p 9222:9222 \
  us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.5 \
  op-node \
  --l1="$L1_RPC_URL" \
  --l1.beacon="$L1_BEACON_URL" \
  --l2=http://op-geth:8551 \
  --l2.jwt-secret=/jwt.txt \
  --rollup.config=/rollup.json \
  --p2p.disable \
  --rpc.addr=0.0.0.0 \
  --rpc.port=9222 \
  --log.level=info

echo ""
echo "OP Stack L2 sync running!"
echo "  op-geth RPC : http://localhost:8545"
echo "  op-node RPC : http://localhost:9222"
echo ""
echo "Check sync:"
echo "  docker logs vessel-op-geth-${CHAIN_ID} -f"
echo "  curl -s -X POST http://localhost:8545 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
