#!/usr/bin/env bash
# Vessel Oracle — Sync to fleet L2 chain (Chain ID: 20260619)
# Run: bash sync-chain.sh
# Requires: docker

set -e

CHAIN_ID=20260619
SERVER_RPC="http://141.11.156.4:8545"
ENODE="enode://977e5865fb597d1c30780c15eff2af222afa994d83bfc1a9e5c9c41f0491a9284e32fe43052e9014d809db94e2f38a85ccef857f87d470e060dc75d88d7fd4d2@141.11.156.4:30303"
DATADIR="$HOME/.vessel-sync-${CHAIN_ID}"

mkdir -p "$DATADIR"

# Write genesis.json (from server block 0)
cat > "$DATADIR/genesis.json" <<'EOF'
{
  "config": {
    "chainId": 20260619,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "clique": { "period": 2, "epoch": 30000 }
  },
  "difficulty": "0x1",
  "gasLimit": "0x1c9c380",
  "extraData": "0x00000000000000000000000000000000000000000000000000000000000000000c849857250fb8cb3fc13e25580a13e7547c9b600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "alloc": {}
}
EOF

echo "✅ genesis.json written"

# Run geth sync node via Docker
docker run -d \
  --name vessel-sync-${CHAIN_ID} \
  -v "$DATADIR:/data" \
  -p 8545:8545 \
  -p 30303:30303/tcp \
  -p 30303:30303/udp \
  ethereum/client-go:v1.13.15 \
  --datadir /data \
  --networkid ${CHAIN_ID} \
  --syncmode full \
  --gcmode archive \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api eth,net,web3,admin \
  --http.vhosts "*" \
  --http.corsdomain "*" \
  --bootnodes "$ENODE" \
  init /data/genesis.json 2>/dev/null || true

# Actually need to init first then run
docker rm -f vessel-sync-${CHAIN_ID} 2>/dev/null || true

echo "⚙️  Initializing geth datadir..."
docker run --rm \
  -v "$DATADIR:/data" \
  ethereum/client-go:v1.13.15 \
  init --datadir /data /data/genesis.json

echo "🚀 Starting sync node..."
docker run -d \
  --name vessel-sync-${CHAIN_ID} \
  -v "$DATADIR:/data" \
  -p 18547:8545 \
  -p 30305:30303/tcp \
  -p 30305:30303/udp \
  ethereum/client-go:v1.13.15 \
  --datadir /data \
  --networkid ${CHAIN_ID} \
  --syncmode full \
  --gcmode archive \
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --http.api eth,net,web3,admin \
  --http.vhosts "*" --http.corsdomain "*" \
  --bootnodes "$ENODE"

echo ""
echo "✅ Sync node running!"
echo "   Local RPC : http://localhost:18547"
echo "   Server RPC: $SERVER_RPC"
echo ""
echo "Check sync:"
echo "  docker logs vessel-sync-${CHAIN_ID} -f"
echo "  curl -s -X POST http://localhost:18547 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
