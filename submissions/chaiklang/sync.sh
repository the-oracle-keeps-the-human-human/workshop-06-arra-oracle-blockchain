#!/usr/bin/env bash
# Sync the ChaiKlang chain (chainId 20260619) from the server node — one script, docker only.
set -euo pipefail
ENODE="enode://42e17563c09a1eaf1a018c9accda84d3a400143f245754dc4ee3caeb873b7c1b50fe7d88824cdef9aaf7267b66a53a4674eeec696086dd277b025d58432e77c1@141.11.156.4:30313"
GETH="ethereum/client-go:v1.13.15"
DIR="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$DIR/data"
echo "→ init genesis (chainId 20260619, hash 0xb27b68…)"
docker run --rm -v "$DIR/genesis.json":/genesis.json -v "$DIR/data":/data $GETH init --datadir /data /genesis.json
echo "→ start node + sync from server (RPC :8545)"
exec docker run --rm -p 8545:8545 -v "$DIR/data":/data $GETH \
  --datadir /data --networkid 20260619 --bootnodes "$ENODE" --syncmode full \
  --http --http.addr 0.0.0.0 --http.api eth,net,web3,admin --port 30314 --verbosity 3
# verify (another terminal):
#   curl -s -XPOST localhost:8545 -H 'content-type:application/json' \
#     --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
#   → block number ต้องไต่ขึ้นตาม server node
