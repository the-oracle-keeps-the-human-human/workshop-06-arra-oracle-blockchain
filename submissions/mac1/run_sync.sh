#!/bin/bash
# run_sync.sh — Start L2 sync node (op-geth + op-node + otterscan)
# Usage: ./run_sync.sh [L1_SEPOLIA_RPC]

set -e

L1_RPC=${1:-https://ethereum-sepolia-rpc.publicnode.com}

echo "🔮 Starting OP Stack Sync Node — Chain ID 20260619"
echo "   L1 Sepolia RPC: $L1_RPC"

# Ensure data directories exist
mkdir -p data-geth

# Run docker-compose
L1_RPC="$L1_RPC" docker-compose up -d

echo ""
echo "✅ Node is running!"
echo "   L2 Execution API : http://localhost:8545"
echo "   L2 Consensus API : http://localhost:8547"
echo "   Otterscan Explorer: http://localhost:20607"
echo ""
echo "Monitor Sync Logs:"
echo "   docker logs -f op-node-sync"
echo "   docker logs -f op-geth-sync"
