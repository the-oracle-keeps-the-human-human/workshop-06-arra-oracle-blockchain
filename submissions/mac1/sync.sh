#!/bin/bash
# sync.sh — Automatically setup and run L2 follower sync node
set -e

mkdir -p opstack-sync && cd opstack-sync

echo "Generating JWT secret (jwt.txt)..."
openssl rand -hex 32 > jwt.txt
chmod 600 jwt.txt

echo "Downloading rollup.json..."
curl -sSL "https://gist.githubusercontent.com/MEYD-605/d92c0fc8fcd3feacfaa52cbfb6f37f1c/raw/rollup.json" -o rollup.json

echo "Downloading docker-compose.yml..."
curl -sSL "https://gist.githubusercontent.com/MEYD-605/d92c0fc8fcd3feacfaa52cbfb6f37f1c/raw/docker-compose.yml" -o docker-compose.yml

echo "Downloading genesis.json (9.1MB)..."
curl -sSL "https://gist.githubusercontent.com/MEYD-605/d92c0fc8fcd3feacfaa52cbfb6f37f1c/raw/genesis.json" -o genesis.json

echo "Starting op-geth and op-node containers..."
docker-compose up -d

echo ""
echo "=================================================="
echo "🎉 OP Stack L2 Follower Sync Node Started successfully!"
echo "=================================================="
echo "L2 JSON-RPC: http://localhost:8545"
echo "L2 Consensus: http://localhost:8547"
echo "Otterscan:    http://localhost:20607"
echo ""
echo "Monitor logs:"
echo "  docker-compose logs -f op-node-sync"
echo "  docker-compose logs -f op-geth-sync"
