#!/bin/bash
set -e

# Configuration
DATADIR="./data"
GENESIS_FILE="genesis.json"
SERVER_IP="141.11.156.4"
SERVER_USER="oracle-school"
SERVER_PATH="~/workshop-06-arra-oracle-blockchain/genesis.json"

echo "=== Initializing Local Synced Node with Docker ==="

# 1. Fetch genesis.json from server via SCP
echo "Fetching genesis.json from server ($SERVER_IP)..."
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP:$SERVER_PATH" "$GENESIS_FILE"
echo "genesis.json successfully copied from server."

# 2. Initialize Geth datadir in Docker
echo "Initializing Geth database inside Docker..."
docker run --rm \
  -v "$(pwd)/$DATADIR":/data \
  -v "$(pwd)/$GENESIS_FILE":/genesis.json \
  ethereum/client-go:v1.13.15 init /genesis.json

echo "=== Docker Geth Init Complete ==="
