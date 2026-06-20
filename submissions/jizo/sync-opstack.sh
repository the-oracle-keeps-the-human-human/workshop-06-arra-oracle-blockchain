#!/bin/bash
# Jizo 🗿 — Nova OP Stack L2 follower (chain 20260619), L1-derivation sync.
# Syncs an independent follower by deriving the L2 from Sepolia L1 — no sequencer RPC needed.
# Proven 2026-06-20: follower block hashes match Nova's canonical chain exactly.
#
# Usage:  bash sync-opstack.sh        (needs: docker, curl, openssl)
set -euo pipefail

SRC="${SRC:-http://141.11.156.4:8181}"                 # Nova file server (genesis + rollup)
L1="${L1:-https://ethereum-sepolia-rpc.publicnode.com}"
BEACON="${BEACON:-https://ethereum-sepolia-beacon-api.publicnode.com}"  # EIP-4844 blobs
GETH_IMG="${GETH_IMG:-us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest}"
NODE_IMG="${NODE_IMG:-us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:latest}"
D="$(pwd)"

echo "==> fetch genesis + rollup from sequencer"
curl -fsS "$SRC/genesis.json" -o genesis.json
curl -fsS "$SRC/rollup.json"  -o rollup.json
[ -f jwt.txt ] || openssl rand -hex 32 > jwt.txt

echo "==> op-geth init (note the genesis hash — it must match the chain)"
rm -rf data
docker run --rm -v "$D":/d "$GETH_IMG" init --datadir /d/data /d/genesis.json 2>&1 | grep -i hash

echo "==> start op-geth (engine API + jwt)"
docker rm -f nova-foll-geth nova-foll-node >/dev/null 2>&1 || true
docker run -d --name nova-foll-geth --network host -v "$D":/d "$GETH_IMG" \
  --datadir /d/data --http --http.addr 127.0.0.1 --http.port 9546 --http.api eth,net,web3 \
  --authrpc.addr 127.0.0.1 --authrpc.port 8551 --authrpc.jwtsecret /d/jwt.txt --authrpc.vhosts='*' \
  --syncmode full --maxpeers 0 --nodiscover --port 30399 --rollup.disabletxpoolgossip
sleep 4

echo "==> start op-node (derive L2 from Sepolia L1 + beacon blobs)"
docker run -d --name nova-foll-node --network host -v "$D":/d "$NODE_IMG" op-node \
  --l1="$L1" --l1.beacon="$BEACON" --l1.trustrpc --l1.rpckind=standard \
  --l2=http://127.0.0.1:8551 --l2.jwt-secret=/d/jwt.txt --rollup.config=/d/rollup.json \
  --rpc.addr=127.0.0.1 --rpc.port=9547 --p2p.no-discovery

echo "==> watch safe_l2 climb from 0 (Ctrl-C to stop)"
while true; do
  curl -s -X POST -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' http://127.0.0.1:9547 \
    | python3 -c "import sys,json;d=json.load(sys.stdin).get('result',{});print('safe_l2',d.get('safe_l2',{}).get('number'),'unsafe_l2',d.get('unsafe_l2',{}).get('number'))" 2>/dev/null || echo "op-node warming up..."
  sleep 15
done
