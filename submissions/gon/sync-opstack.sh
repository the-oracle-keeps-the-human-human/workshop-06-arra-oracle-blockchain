#!/bin/bash
# Gon Oracle — OP Stack L2 Sync Script
# Sync a follower node to Nova's L2 chain (Chain ID: 20260619)
# First comes rock! 🪨✊
set -e

NOVA_SEQUENCER="${NOVA_SEQUENCER:-141.11.156.4}"
NOVA_P2P_PORT="${NOVA_P2P_PORT:-9227}"
NOVA_PEER_ID="${NOVA_PEER_ID:-16Uiu2HAmHdqUpiFA4y9ftVzNvoDPUvuAkFr6irdWP8zjCN2ZNqVa}"
L1_RPC="${L1_RPC:-https://ethereum-sepolia-rpc.publicnode.com}"
L1_BEACON="${L1_BEACON:-https://ethereum-sepolia-beacon-api.publicnode.com}"
CHAIN_ID=20260619

DATA_DIR="${DATA_DIR:-./gon-op-data}"
GETH_HTTP="${GETH_HTTP:-8545}"
GETH_AUTHRPC="${GETH_AUTHRPC:-8551}"
OPNODE_HTTP="${OPNODE_HTTP:-9545}"
P2P_PORT="${P2P_PORT:-9300}"

echo "=== 🪨 Gon OP Stack L2 Sync Node ==="
echo "Chain ID:   $CHAIN_ID"
echo "Sequencer:  $NOVA_SEQUENCER"
echo "Nova P2P:   /ip4/$NOVA_SEQUENCER/tcp/$NOVA_P2P_PORT/p2p/$NOVA_PEER_ID"
echo ""

# --- Step 1: Check binaries ---
echo "[1/5] Checking binaries..."
for bin in op-geth op-node; do
    if ! command -v "$bin" &>/dev/null; then
        echo "❌ $bin not found. Install:"
        echo "  op-geth: git clone https://github.com/ethereum-optimism/op-geth && cd op-geth && make geth"
        echo "  op-node: git clone https://github.com/ethereum-optimism/optimism && cd optimism/op-node && make op-node"
        exit 1
    fi
done
echo "✅ op-geth + op-node found"

# --- Step 2: Get genesis.json ---
echo "[2/5] Getting genesis.json..."
if [ ! -f genesis.json ]; then
    echo "  Downloading from sequencer..."
    curl -sf -o genesis.json "http://$NOVA_SEQUENCER:8181/genesis.json" || {
        echo "❌ Failed to download genesis.json"
        echo "  Try: curl http://$NOVA_SEQUENCER:8181/genesis.json -o genesis.json"
        exit 1
    }
    echo "✅ genesis.json downloaded ($(wc -c < genesis.json) bytes)"
else
    echo "✅ genesis.json exists"
fi

# --- Step 3: Get rollup.json ---
echo "[3/5] Getting rollup.json..."
if [ ! -f rollup.json ]; then
    echo "❌ rollup.json not found"
    echo "  Copy from: submissions/nova/rollup.json"
    exit 1
fi
echo "✅ rollup.json exists"

# --- Step 4: Generate JWT ---
echo "[4/5] Setting up JWT..."
JWT_FILE="$DATA_DIR/jwt.txt"
mkdir -p "$DATA_DIR"
if [ ! -f "$JWT_FILE" ]; then
    openssl rand -hex 32 > "$JWT_FILE"
    echo "✅ JWT secret generated"
else
    echo "✅ JWT secret exists"
fi

# --- Step 5: Init + Run ---
echo "[5/5] Initializing geth..."
op-geth init --datadir "$DATA_DIR" genesis.json 2>/dev/null || true

echo ""
echo "=== Starting op-geth (follower) ==="
op-geth \
    --datadir "$DATA_DIR" \
    --http --http.addr 0.0.0.0 --http.port "$GETH_HTTP" \
    --http.api eth,net,web3,debug,txpool \
    --http.corsdomain "*" --http.vhosts "*" \
    --ws --ws.addr 0.0.0.0 --ws.port $((GETH_HTTP + 1)) \
    --ws.api eth,net,web3,debug,txpool \
    --authrpc.addr 0.0.0.0 --authrpc.port "$GETH_AUTHRPC" \
    --authrpc.jwtsecret "$JWT_FILE" \
    --syncmode full \
    --gcmode archive \
    --networkid "$CHAIN_ID" \
    --nodiscover \
    --maxpeers 0 \
    --rollup.sequencerhttp "http://$NOVA_SEQUENCER:9545" \
    --rollup.disabletxpoolgossip \
    &
GETH_PID=$!
echo "op-geth started (PID: $GETH_PID)"
sleep 5

echo ""
echo "=== Starting op-node (follower) ==="
op-node \
    --l1 "$L1_RPC" \
    --l1.beacon "$L1_BEACON" \
    --l2 "http://localhost:$GETH_AUTHRPC" \
    --l2.jwt-secret "$JWT_FILE" \
    --rollup.config rollup.json \
    --rpc.addr 0.0.0.0 --rpc.port "$OPNODE_HTTP" \
    --p2p.listen.tcp "$P2P_PORT" \
    --p2p.static "/ip4/$NOVA_SEQUENCER/tcp/$NOVA_P2P_PORT/p2p/$NOVA_PEER_ID" \
    --sequencer.enabled=false \
    &
OPNODE_PID=$!
echo "op-node started (PID: $OPNODE_PID)"

echo ""
echo "=== 🪨 Gon L2 Sync Running ==="
echo "op-geth HTTP: http://localhost:$GETH_HTTP"
echo "op-node HTTP: http://localhost:$OPNODE_HTTP"
echo "P2P port:     $P2P_PORT"
echo ""
echo "Check sync: curl -s http://localhost:$GETH_HTTP -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
echo ""
echo "Press Ctrl+C to stop"

trap "kill $GETH_PID $OPNODE_PID 2>/dev/null; echo 'Stopped.'" EXIT
wait
