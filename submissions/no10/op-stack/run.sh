#!/bin/bash
# run.sh - Prepare environment and start L2 OP Stack sync node

set -e

# 1. Generate JWT secret for Engine API if not exists
if [ ! -f jwt.txt ]; then
    echo "🔑 Generating JWT Secret..."
    openssl rand -hex 32 > jwt.txt
fi

# 2. Check and prepare default configuration files (.env, genesis.json, rollup.json)
if [ ! -f .env ]; then
    echo "📝 Creating default .env configuration..."
    cat << 'EOF' > .env
L1_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON_URL=https://ethereum-sepolia-beacon-api.publicnode.com
OP_NODE_BOOTNODES=""
EOF
fi

if [ ! -f genesis.json ]; then
    echo "⚠️ genesis.json is missing! Creating placeholder genesis.json..."
    echo "{}" > genesis.json
fi

if [ ! -f rollup.json ]; then
    echo "⚠️ rollup.json is missing! Creating placeholder rollup.json..."
    echo "{}" > rollup.json
fi

# 3. Create folder for Geth DB storage
mkdir -p geth-data

# 4. Initialize Geth database with genesis.json if not already initialized
if [ ! -d geth-data/geth ]; then
    echo "🧱 Initializing Geth database with genesis.json..."
    docker run --rm \
      -v "$(pwd)/geth-data:/db" \
      -v "$(pwd)/genesis.json:/config/genesis.json" \
      us-docker.pkg.dev/oplabs-tools-and-services/images/op-geth:latest \
      geth init --datadir=/db /config/genesis.json
fi

# 5. Start the Docker-compose services
echo "🚀 Starting OP Stack Sync Node (op-geth + op-node)..."
docker compose up -d
