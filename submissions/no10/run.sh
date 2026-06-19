#!/bin/bash
# run.sh - Build and Run FloodBoy Ingester in Docker

set -e

# 1. Build the Docker image
echo "🔨 Building docker image..."
docker build -t floodboy-ingest .

# 2. Prepare state.json on host to prevent Docker mounting it as a folder
if [ ! -f state.json ]; then
    echo "📝 Creating empty state.json..."
    echo "{}" > state.json
fi

# 3. Ensure data directory exists
mkdir -p data

# 4. Run the container in incremental mode
# Mount data/ folder and state.json for data persistence
echo "🚀 Running floodboy-ingest in Docker..."
docker run --rm \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/state.json:/app/state.json" \
  floodboy-ingest incremental
