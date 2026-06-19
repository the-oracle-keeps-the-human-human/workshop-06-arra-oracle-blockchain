#!/bin/bash
# Nova OP Stack L2 Sync Script
# Syncs a follower node to the Nova L2 OP Stack chain
set -e

NOVA_SEQUENCER="${NOVA_SEQUENCER:-141.11.156.4}"
L1_RPC="${L1_RPC:-https://ethereum-sepolia-rpc.publicnode.com}"
L1_BEACON="${L1_BEACON:-https://ethereum-sepolia-beacon-api.publicnode.com}"
DATA_DIR="${DATA_DIR:-./op-geth-data}"
OP_GETH="${OP_GETH:-op-geth}"
OP_NODE="${OP_NODE:-op-node}"
PORT_HTTP="${PORT_HTTP:-8555}"
PORT_AUTHRPC="${PORT_AUTHRPC:-8664}"
PORT_P2P="${PORT_P2P:-30315}"

echo "=== Nova OP Stack L2 Sync Node ==="
echo "Sequencer: $NOVA_SEQUENCER"
echo "Chain ID:  20260619"
echo ""

# Check binaries
for bin in "$OP_GETH" "$OP_NODE"; do
    if ! command -v "$bin" &>/dev/null && [ ! -x "$bin" ]; then
        echo "ERROR: $bin not found. Build from source or install."
        echo "  op-geth: git clone https://github.com/ethereum-optimism/op-geth && cd op-geth && go run build/ci.go install ./cmd/geth"
        echo "  op-node: git clone https://github.com/ethereum-optimism/optimism && cd optimism/op-node && go build ./cmd/"
        exit 1
    fi
done

# Download genesis if not present
if [ ! -f genesis.json ]; then
    echo "Downloading genesis.json from sequencer..."
    # Genesis is 9.5MB - get it from the sequencer or ask Nova
    if curl -s -o genesis.json "http://$NOVA_SEQUENCER:8555/genesis.json" 2>/dev/null; then
        echo "  ✓ genesis.json downloaded"
    else
        echo "  ⚠ Could not download genesis.json — copy it from submissions/nova/genesis.json"
        echo "  Or ask Nova to provide it."
        exit 1
    fi
fi

# Check rollup.json
if [ ! -f rollup.json ]; then
    echo "ERROR: rollup.json not found. Copy from submissions/nova/rollup.json"
    exit 1
fi

# Generate JWT secret
if [ ! -f jwt.txt ]; then
    echo "Generating JWT secret..."
    openssl rand -hex 32 > jwt.txt
    chmod 600 jwt.txt
    echo "  ✓ jwt.txt generated"
fi

# Init op-geth
if [ ! -d "$DATA_DIR/geth" ]; then
    echo "Initializing op-geth with genesis..."
    $OP_GETH init --datadir "$DATA_DIR" genesis.json
    echo "  ✓ op-geth initialized"
fi

# Kill any existing processes on our ports
lsof -ti:$PORT_HTTP 2>/dev/null | xargs kill -9 2>/dev/null || true
lsof -ti:$PORT_AUTHRPC 2>/dev/null | xargs kill -9 2>/dev/null || true

# Start op-geth (execution)
echo "Starting op-geth..."
$OP_GETH \
    --datadir "$DATA_DIR" \
    --networkid 20260619 \
    --http --http.addr 0.0.0.0 --http.port "$PORT_HTTP" \
    --http.api eth,net,web3 \
    --authrpc.addr 127.0.0.1 --authrpc.port "$PORT_AUTHRPC" \
    --authrpc.jwtsecret jwt.txt \
    --authrpc.vhosts '*' \
    --port "$PORT_P2P" --nodiscover \
    --syncmode full \
    --verbosity 3 \
    > op-geth.log 2>&1 &

GETH_PID=$!
echo "  op-geth PID: $GETH_PID (logs: op-geth.log)"

# Wait for op-geth RPC
echo "Waiting for op-geth RPC..."
for i in $(seq 1 30); do
    if curl -s -X POST "http://127.0.0.1:$PORT_HTTP" \
        -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        2>/dev/null | grep -q "0x135270b"; then
        echo "  ✓ op-geth ready"
        break
    fi
    sleep 2
done

# Start op-node (consensus)
echo "Starting op-node..."
$OP_NODE \
    --l2="http://127.0.0.1:$PORT_AUTHRPC" \
    --l2.jwt-secret=jwt.txt \
    --l2.enginekind=geth \
    --l1="$L1_RPC" \
    --l1.beacon="$L1_BEACON" \
    --rollup.config=rollup.json \
    --rpc.addr=0.0.0.0 --rpc.port=8655 \
    > op-node.log 2>&1 &

NODE_PID=$!
echo "  op-node PID: $NODE_PID (logs: op-node.log)"

echo ""
echo "=== L2 Node Started ==="
echo "op-geth RPC:  http://127.0.0.1:$PORT_HTTP"
echo "op-node RPC:  http://127.0.0.1:8655"
echo ""
echo "Check sync status:"
echo "  curl -X POST http://127.0.0.1:8655 -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"optimism_syncStatus\",\"params\":[],\"id\":1}'"
echo ""
echo "Check blocks:"
echo "  curl -X POST http://127.0.0.1:$PORT_HTTP -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
