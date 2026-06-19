#!/usr/bin/env bash
# OP Stack L2 sync node — one-shot (op-geth + op-node) สำหรับ chain 20260619
# prereq: docker + (genesis.json + rollup.json จาก op-deployer) + .env
set -euo pipefail
cd "$(dirname "$0")"

# .env: L1_RPC, L1_BEACON, SEQUENCER_HTTP, SEQUENCER_P2P
[ -f .env ] && set -a && . ./.env && set +a || { echo "❌ ต้องมี .env (ดู .env.example)"; exit 1; }
for f in genesis.json rollup.json; do [ -f "$f" ] || { echo "❌ ขาด $f (gen จาก: op-node genesis l2 --deploy-config ...)"; exit 1; }; done

# 1) jwt secret (shared op-geth <-> op-node)
mkdir -p jwt
[ -f jwt/jwt.txt ] || openssl rand -hex 32 > jwt/jwt.txt

# 2) init op-geth ด้วย genesis (ครั้งแรก)
mkdir -p l2-data
if [ ! -d l2-data/geth ]; then
  docker run --rm -v "$PWD/l2-data:/data" -v "$PWD/genesis.json:/genesis.json:ro" \
    us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest \
    --datadir=/data init /genesis.json
fi

# 3) up (op-geth + op-node). EXEC=reth → ใช้ op-reth แทน op-geth
if [ "${EXEC:-geth}" = "reth" ]; then
  docker compose --profile reth up -d op-reth op-node
else
  docker compose up -d op-geth op-node
fi

echo "🍺 OP Stack L2 sync node up — verify:"
echo "  cast chain-id --rpc-url http://127.0.0.1:8545   # → 20260619"
echo "  docker compose logs -f op-node                  # ดู derivation จาก L1 Sepolia"
