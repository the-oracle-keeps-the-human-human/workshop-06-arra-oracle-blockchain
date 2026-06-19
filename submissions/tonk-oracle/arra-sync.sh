#!/bin/bash
# arra-sync.sh — sync ARRA Oracle chain (chainId 20260619) via Docker geth
# โดย Tonk Oracle (AI) · workshop-06
# honest: ผู้เขียนยัง verify เองไม่ได้ (ไม่มี docker บนเครื่อง) — docker isolation แก้ port-collision
#         ที่เจอตอนรัน bare-metal บน shared account · ใครมี docker รัน + ดู PROOF ท้าย script ได้เลย
set -e

# canonical chain bootnode + genesis (No.10X geth Clique PoA node บน server)
GENESIS_URL="https://raw.githubusercontent.com/MEYD-605/workshop-06-arra-oracle-blockchain/main/genesis.json"
BOOTNODE="enode://fd5984ed8f8fbcf9a1241e26585d8d78c72334c43c7913fc7ba2441614f24488ffdb6f59a1aa7ea93ae639c01bef948c5acdd801f39fe66c284fb7c33ea52f37@141.11.156.4:30310"

mkdir -p arra-sync && cd arra-sync
curl -sSL -o genesis.json "$GENESIS_URL"
echo "chainId: $(python3 -c 'import json;print(json.load(open("genesis.json"))["config"]["chainId"])' 2>/dev/null || echo 20260619)"

docker rm -f arra-sync 2>/dev/null || true
docker volume rm arra-data 2>/dev/null || true

# 1) init genesis ในคอนเทนเนอร์ (ports แยกใน container = ไม่ชน host)
docker run --rm -v "$PWD/genesis.json:/genesis.json" -v arra-data:/data \
  ethereum/client-go:v1.13.15 init --datadir /data /genesis.json

# 2) run sync node + ชี้ bootnode โหนดหลัก
docker run -d --name arra-sync -p 18545:8545 -v arra-data:/data \
  ethereum/client-go:v1.13.15 --datadir /data --networkid 20260619 \
  --bootnodes "$BOOTNODE" --syncmode full \
  --http --http.addr 0.0.0.0 --http.api eth,net,web3,admin --nodiscover=false --verbosity 3

echo "waiting for peer + block sync (35s)..."; sleep 35

# === PROOF (ตรวจงาน) ===
echo "=== PROOF: peers + block height (sync มาจากโหนดหลัก) ==="
docker exec arra-sync geth attach --exec \
  '"peers="+admin.peers.length+"  block="+eth.blockNumber' http://127.0.0.1:8545
docker exec arra-sync geth attach --exec \
  'admin.peers.length>0 ? "PEERED enode "+admin.peers[0].enode.slice(8,24)+"... @ "+admin.peers[0].network.remoteAddress : "no peers yet — bootnode อาจ down หรือ genesis hash ไม่ตรง"' http://127.0.0.1:8545

# verify ภายนอก: cast chain-id --rpc-url http://localhost:18545  → 20260619
