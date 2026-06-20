#!/bin/bash
# Jizo 🗿 — OP Stack L2 Sync Script (hardened adaptation of Nova's sync-opstack.sh)
# Chain: Nova L2 (chainId 20260619) on Sepolia L1
#
# HONEST NOTICE: As of 2026-06-20, Nova's sequencer (141.11.156.4) is UNREACHABLE and
# genesis.json is NOT in the repo. This script will detect those blockers and FAIL LOUDLY
# rather than silently proceeding to a broken state.
#
# Usage: L1_RPC=<url> ./sync-opstack.sh
set -euo pipefail

NOVA_SEQUENCER_IP="${NOVA_SEQUENCER_IP:-141.11.156.4}"
NOVA_SEQ_RPC_PORT="${NOVA_SEQ_RPC_PORT:-8555}"
L1_RPC="${L1_RPC:-https://ethereum-sepolia-rpc.publicnode.com}"
L1_BEACON="${L1_BEACON:-https://ethereum-sepolia-beacon-api.publicnode.com}"
DATA_DIR="${DATA_DIR:-./op-geth-data}"
OP_GETH="${OP_GETH:-op-geth}"
OP_NODE="${OP_NODE:-op-node}"
PORT_HTTP="${PORT_HTTP:-8555}"
PORT_AUTHRPC="${PORT_AUTHRPC:-8664}"
PORT_P2P="${PORT_P2P:-30315}"
PORT_NODE="${PORT_NODE:-8655}"

echo "=== Jizo 🗿 — OP Stack L2 Sync Node ==="
echo "Chain ID: 20260619 (Nova L2)"
echo "L1:       Sepolia (11155111)"
echo "Seq:      $NOVA_SEQUENCER_IP:$NOVA_SEQ_RPC_PORT"
echo ""

# ─────────────────────────────────────────────
# PRE-FLIGHT 1: Sequencer reachability
# ─────────────────────────────────────────────
echo "[preflight] Checking sequencer reachability..."
if curl -s --max-time 6 --connect-timeout 5 \
    "http://$NOVA_SEQUENCER_IP:$NOVA_SEQ_RPC_PORT" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    2>/dev/null | grep -q "0x135270b"; then
    echo "  OK sequencer is reachable (chain 20260619 confirmed)"
else
    echo ""
    echo "  BLOCKER: Cannot reach sequencer at $NOVA_SEQUENCER_IP:$NOVA_SEQ_RPC_PORT"
    echo ""
    echo "  Without the sequencer:"
    echo "    - genesis.json cannot be fetched (it is NOT in the repo)"
    echo "    - op-geth cannot be initialized"
    echo "    - L2 sync cannot proceed"
    echo ""
    echo "  Verified 2026-06-20: curl returned error 7 (connection refused/timeout)."
    echo "  Contact Nova to get genesis.json out-of-band or wait for sequencer to return."
    echo ""
    echo "  FALLBACK: If you have genesis.json from another source, set:"
    echo "    GENESIS_FILE=/path/to/genesis.json ./sync-opstack.sh"
    echo ""
    if [ -z "${GENESIS_FILE:-}" ] || [ ! -f "${GENESIS_FILE:-}" ]; then
        echo "ABORT: sequencer unreachable and no local genesis.json available."
        exit 2
    else
        echo "  Using local genesis from GENESIS_FILE=$GENESIS_FILE"
    fi
fi

# ─────────────────────────────────────────────
# PRE-FLIGHT 2: Binaries
# ─────────────────────────────────────────────
echo "[preflight] Checking binaries..."
missing_bins=0
for bin in "$OP_GETH" "$OP_NODE"; do
    if ! command -v "$bin" &>/dev/null && [ ! -x "./$bin" ]; then
        echo "  MISSING: $bin"
        missing_bins=$((missing_bins + 1))
    else
        echo "  OK $bin"
    fi
done

if [ "$missing_bins" -gt 0 ]; then
    echo ""
    echo "  Build from source (requires Go 1.24+):"
    echo "    git clone --depth 1 https://github.com/ethereum-optimism/op-geth"
    echo "    cd op-geth && go run build/ci.go install ./cmd/geth"
    echo "    git clone --depth 1 https://github.com/ethereum-optimism/optimism"
    echo "    cd optimism/op-node && go build -o ../../op-node ./cmd/"
    echo ""
    echo "  Docker alternative:"
    echo "    docker pull us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest"
    echo ""
    echo "ABORT: missing required binaries."
    exit 3
fi

# ─────────────────────────────────────────────
# PRE-FLIGHT 3: L1 RPC reachable
# ─────────────────────────────────────────────
echo "[preflight] Checking L1 RPC..."
if curl -s --max-time 10 -X POST "$L1_RPC" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    2>/dev/null | grep -q "0xaa36a7"; then
    echo "  OK L1 RPC (Sepolia chainId=11155111 confirmed)"
else
    echo "  WARNING: L1 RPC $L1_RPC did not return Sepolia chainId. Check L1_RPC variable."
fi

# ─────────────────────────────────────────────
# PRE-FLIGHT 4: rollup.json
# ─────────────────────────────────────────────
echo "[preflight] Checking rollup.json..."
ROLLUP_JSON="${ROLLUP_JSON:-rollup.json}"
if [ ! -f "$ROLLUP_JSON" ]; then
    echo "  MISSING: rollup.json not found at $ROLLUP_JSON"
    echo "  Copy from submissions/nova/rollup.json (chainId=20260619)"
    echo "ABORT: rollup.json required."
    exit 4
fi
if python3 -c "import json,sys; d=json.load(open('$ROLLUP_JSON')); assert d['l2_chain_id']==20260619" 2>/dev/null; then
    echo "  OK rollup.json (l2_chain_id=20260619 confirmed)"
else
    echo "  WARNING: rollup.json present but could not verify l2_chain_id."
fi

# ─────────────────────────────────────────────
# Fetch genesis.json
# ─────────────────────────────────────────────
GENESIS_FILE="${GENESIS_FILE:-genesis.json}"
if [ ! -f "$GENESIS_FILE" ]; then
    echo "[init] Downloading genesis.json from sequencer (~9.5MB)..."
    if curl -s --max-time 60 -o "$GENESIS_FILE" \
        "http://$NOVA_SEQUENCER_IP:$NOVA_SEQ_RPC_PORT/genesis.json" 2>/dev/null; then
        GSIZE=$(wc -c < "$GENESIS_FILE")
        if [ "$GSIZE" -lt 1000000 ]; then
            echo "  WARNING: genesis.json is suspiciously small ($GSIZE bytes, expected ~9.5MB)"
            rm -f "$GENESIS_FILE"
            echo "ABORT: genesis.json download failed (got error page?)."
            exit 5
        fi
        echo "  OK genesis.json ($GSIZE bytes)"
    else
        echo "  FAILED: could not download genesis.json (sequencer unreachable)"
        echo "ABORT: genesis.json unavailable."
        exit 5
    fi
else
    echo "[init] Using existing genesis.json"
fi

# ─────────────────────────────────────────────
# JWT secret
# ─────────────────────────────────────────────
if [ ! -f jwt.txt ]; then
    echo "[init] Generating JWT secret..."
    openssl rand -hex 32 > jwt.txt
    chmod 600 jwt.txt
    echo "  OK jwt.txt"
fi

# ─────────────────────────────────────────────
# Init op-geth
# ─────────────────────────────────────────────
if [ ! -d "$DATA_DIR/geth" ]; then
    echo "[init] Initializing op-geth with genesis..."
    "$OP_GETH" init --datadir "$DATA_DIR" "$GENESIS_FILE" 2>&1 | tail -5
    echo "  OK op-geth initialized"
fi

# ─────────────────────────────────────────────
# Start op-geth (execution layer)
# ─────────────────────────────────────────────
echo "[start] Starting op-geth..."
"$OP_GETH" \
    --datadir "$DATA_DIR" \
    --networkid 20260619 \
    --http --http.addr 0.0.0.0 --http.port "$PORT_HTTP" \
    --http.api eth,net,web3 \
    --authrpc.addr 127.0.0.1 --authrpc.port "$PORT_AUTHRPC" \
    --authrpc.jwtsecret jwt.txt \
    --authrpc.vhosts '*' \
    --port "$PORT_P2P" \
    --nodiscover \
    --syncmode full \
    --verbosity 3 \
    > op-geth.log 2>&1 &
GETH_PID=$!
echo "  op-geth PID: $GETH_PID (logs: op-geth.log)"

echo "[wait] Waiting for op-geth RPC (up to 60s)..."
for i in $(seq 1 30); do
    if curl -s --max-time 2 -X POST "http://127.0.0.1:$PORT_HTTP" \
        -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        2>/dev/null | grep -q "0x135270b"; then
        echo "  OK op-geth ready"
        break
    fi
    sleep 2
done

# ─────────────────────────────────────────────
# Start op-node (consensus/derivation)
# ─────────────────────────────────────────────
echo "[start] Starting op-node..."
"$OP_NODE" \
    --l2="http://127.0.0.1:$PORT_AUTHRPC" \
    --l2.jwt-secret=jwt.txt \
    --l2.enginekind=geth \
    --l1="$L1_RPC" \
    --l1.beacon="$L1_BEACON" \
    --rollup.config="$ROLLUP_JSON" \
    --rpc.addr=0.0.0.0 --rpc.port="$PORT_NODE" \
    > op-node.log 2>&1 &
NODE_PID=$!
echo "  op-node PID: $NODE_PID (logs: op-node.log)"

echo ""
echo "=== L2 Node Started ==="
echo "op-geth RPC:  http://127.0.0.1:$PORT_HTTP"
echo "op-node RPC:  http://127.0.0.1:$PORT_NODE"
echo ""
echo "Verify sync status:"
echo "  curl -s -X POST http://127.0.0.1:$PORT_NODE -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"optimism_syncStatus\",\"params\":[],\"id\":1}'"
