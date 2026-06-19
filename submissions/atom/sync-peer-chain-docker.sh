#!/usr/bin/env bash
set -euo pipefail

# Docker Geth P2P sync checker for Oracle School shared Geth/Clique chain.
# Safe behavior: it refuses to sync if genesis hash does not match.
# Usage:
#   mkdir -p .oracle-peer-sync
#   cp genesis.json .oracle-peer-sync/genesis.json
#   cd .oracle-peer-sync
#   bash sync-peer-chain-docker.sh
#
# Optional overrides:
#   NAME=oracle-peer-sync RPC_PORT=18545 P2P_PORT=30403 bash sync-peer-chain-docker.sh

NAME="${NAME:-oracle-peer-sync}"
IMAGE="${IMAGE:-ethereum/client-go:v1.13.15}"
NETWORK_ID="${NETWORK_ID:-20260619}"
RPC_PORT="${RPC_PORT:-18545}"
P2P_PORT="${P2P_PORT:-30403}"
SERVER_RPC="${SERVER_RPC:-http://141.11.156.4:8545}"
SERVER_ENODE="${SERVER_ENODE:-enode://977e5865fb597d1c30780c15eff2af222afa994d83bfc1a9e5c9c41f0491a9284e32fe43052e9014d809db94e2f38a85ccef857f87d470e060dc75d88d7fd4d2@141.11.156.4:30303}"
EXPECTED_GENESIS="${EXPECTED_GENESIS:-0xedf353cfb2c912258f26214e01468a5af5335c5bfc35fea55bd6772234242906}"
DATADIR="/gethdata"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need docker
need curl

if [ ! -f genesis.json ]; then
  cat >&2 <<MSG
ERROR: missing genesis.json
Put the exact genesis.json for the peer chain in this directory first.
This script intentionally does not guess genesis, because wrong genesis = wrong chain.
MSG
  exit 1
fi

rpc_server() {
  local method="$1"
  curl -sS -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":[]}" \
    "$SERVER_RPC"
}

rpc_local() {
  local method="$1"
  curl -sS -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":[]}" \
    "http://127.0.0.1:${RPC_PORT}"
}

echo "[1/6] server check"
echo "server chainId: $(rpc_server eth_chainId)"
echo "server head   : $(rpc_server eth_blockNumber)"

echo "[2/6] cleanup"
docker rm -f "$NAME" >/dev/null 2>&1 || true
rm -rf data
mkdir -p data

echo "[3/6] init genesis"
docker run --rm -v "$PWD:/work" "$IMAGE" \
  init --datadir /work/data /work/genesis.json | tee init.log

LOCAL_GENESIS="$(grep -Eo 'hash=[0-9a-fx]+' init.log | tail -1 | cut -d= -f2 || true)"
echo "local genesis: ${LOCAL_GENESIS:-unknown}"
echo "expect       : $EXPECTED_GENESIS"

if [ "${LOCAL_GENESIS:-}" != "$EXPECTED_GENESIS" ]; then
  echo "ERROR: genesis hash mismatch; refusing to sync wrong chain" >&2
  exit 2
fi

echo "[4/6] start local geth container"
docker run -d --name "$NAME" \
  -v "$PWD/data:$DATADIR" \
  -p "127.0.0.1:${RPC_PORT}:8545" \
  -p "${P2P_PORT}:${P2P_PORT}/tcp" \
  -p "${P2P_PORT}:${P2P_PORT}/udp" \
  "$IMAGE" \
  --datadir "$DATADIR" \
  --networkid "$NETWORK_ID" \
  --port "$P2P_PORT" \
  --syncmode full \
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --http.api eth,net,web3,admin \
  --http.vhosts='*' --http.corsdomain='*' \
  --nodiscover \
  --verbosity 3 >/dev/null

sleep 4

echo "[5/6] add peer"
docker exec "$NAME" geth attach "$DATADIR/geth.ipc" \
  --exec "admin.addPeer('$SERVER_ENODE')"

echo "[6/6] poll proof"
for i in $(seq 1 30); do
  echo "try=$i"
  echo "local block : $(rpc_local eth_blockNumber)"
  echo "server block: $(rpc_server eth_blockNumber)"
  echo "peers       : $(rpc_local net_peerCount)"
  echo "syncing     : $(rpc_local eth_syncing)"
  sleep 5
done

echo "final proof:"
docker exec "$NAME" geth attach "$DATADIR/geth.ipc" \
  --exec 'eth.chainId(); eth.blockNumber; net.peerCount; eth.syncing'
