#!/usr/bin/env bash
# 🐆 ARRA Oracle Chain (20260619) — one-shot Docker sync จาก main node
# รัน: ./sync-arra-chain.sh   → ได้ geth โหนดที่ sync chain หลักบน server (P2P จริง)
set -euo pipefail
WORK="${1:-$PWD/arra-data}"; mkdir -p "$WORK"; cd "$WORK"
IMG="ethereum/client-go:v1.13.15"   # ต้อง 1.13.x — geth ใหม่ (PoS-only) รัน Clique ไม่ได้
MAIN_ENODE="enode://977e5865fb597d1c30780c15eff2af222afa994d83bfc1a9e5c9c41f0491a9284e32fe43052e9014d809db94e2f38a85ccef857f87d470e060dc75d88d7fd4d2@141.11.156.4:30303"

# canonical genesis (tokyo, hash 0xedf353) — ทุกคนต้องใช้ตัวเดียวกัน ไม่งั้น sync ไม่ได้
cat > genesis.json <<'EOF'
{"config":{"chainId":20260619,"homesteadBlock":0,"eip150Block":0,"eip155Block":0,"eip158Block":0,"byzantiumBlock":0,"constantinopleBlock":0,"petersburgBlock":0,"istanbulBlock":0,"muirGlacierBlock":0,"berlinBlock":0,"londonBlock":0,"arrowGlacierBlock":0,"grayGlacierBlock":0,"clique":{"period":5,"epoch":30000}},"difficulty":"1","gasLimit":"30000000","extradata":"0x00000000000000000000000000000000000000000000000000000000000000000c849857250fb8cb3fc13e25580a13e7547c9b600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","alloc":{"0x0c849857250fb8cb3fc13e25580a13e7547c9b60":{"balance":"1000000000000000000000000000"}}}
EOF

docker rm -f arra-node >/dev/null 2>&1 || true
echo "🐆 init genesis (hash ต้อง edf353)..."
docker run --rm -v "$PWD:/data" "$IMG" init --datadir /data/chaindata /data/genesis.json 2>&1 | grep -i hash | head -1
echo "🐆 start geth + sync..."
docker run -d --name arra-node -v "$PWD:/data" -p 18599:8545 "$IMG" \
  --datadir /data/chaindata --networkid 20260619 --syncmode full --nodiscover \
  --http --http.addr 0.0.0.0 --http.api eth,net,admin --verbosity 2 >/dev/null
sleep 8
docker exec arra-node geth attach --exec "admin.addPeer(\"$MAIN_ENODE\")" /data/chaindata/geth.ipc
sleep 10
echo "peers: $(docker exec arra-node geth attach --exec 'net.peerCount' /data/chaindata/geth.ipc)"
echo "block: $(docker exec arra-node geth attach --exec 'eth.blockNumber' /data/chaindata/geth.ipc)"
echo "✅ syncing — RPC ที่ http://localhost:18599"
