#!/usr/bin/env bash
# ============================================================================
# Weizen — ONE-SHOT Docker sync: รัน geth node แล้ว P2P-sync chain 20260619 จาก server
# (geth Clique · official image ethereum/client-go:v1.13.15 · ไม่ใช่ anvil/RPC-read)
#
#   bash sync-docker.sh
#
# verified: genesis hash + block hash ตรง server เป๊ะ (proof block 1196 = 0xdd07c6b7…)
# underlying geth commands ผ่านการ test จริงด้วย geth 1.13.15 binary (block hash match)
# Docker wrapper = ห่อคำสั่งเดิมด้วย official image (≥1.14 ตัด Clique → ต้อง pin v1.13.15)
# ============================================================================
set -euo pipefail

SERVER="${SERVER:-141.11.156.4}"
P2P_PORT="${P2P_PORT:-30310}"
ENODE_PUBKEY="fd5984ed8f8fbcf9a1241e26585d8d78c72334c43c7913fc7ba2441614f24488ffdb6f59a1aa7ea93ae639c01bef948c5acdd801f39fe66c284fb7c33ea52f37"
ENODE="enode://${ENODE_PUBKEY}@${SERVER}:${P2P_PORT}"
IMG="ethereum/client-go:v1.13.15"          # pin: Clique ถูกถอดใน >=1.14
NAME="weizen-sync"
WORK="$(pwd)/weizen-sync-data"
mkdir -p "$WORK/node"

# 1) genesis.json — ตรงกับ server เป๊ะ (genesis hash 0xea75f4d0…510512)
cat > "$WORK/genesis.json" <<'JSON'
{
  "config": {
    "chainId": 20260619,
    "homesteadBlock": 0, "eip150Block": 0, "eip155Block": 0, "eip158Block": 0,
    "byzantiumBlock": 0, "constantinopleBlock": 0, "petersburgBlock": 0,
    "istanbulBlock": 0, "muirGlacierBlock": 0, "berlinBlock": 0, "londonBlock": 0,
    "arrowGlacierBlock": 0, "grayGlacierBlock": 0,
    "clique": { "period": 5, "epoch": 30000 }
  },
  "nonce": "0x0000000000000000",
  "timestamp": "0x0",
  "extraData": "0x00000000000000000000000000000000000000000000000000000000000000004e97e5407bb7495bbc1fb924ae05f156099e219f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x1c9c380",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "baseFeePerGas": "0x3b9aca00",
  "alloc": { "0x4e97e5407bb7495bbc1fb924ae05f156099e219f": { "balance": "1000000000000000000000000000" } }
}
JSON

echo "🍺 [1/4] init genesis (Docker $IMG)"
docker run --rm -v "$WORK:/data" "$IMG" --datadir /data/node init /data/genesis.json 2>&1 | grep -iE "hash|success|fatal" || true

echo "🍺 [2/4] start geth node (peer → $ENODE)"
docker rm -f "$NAME" 2>/dev/null || true
# security: RPC bind loopback-only + read-only namespaces (admin ใช้ผ่าน IPC ไม่ใช่ HTTP)
# --network host จำเป็นสำหรับ outbound P2P dial → server enode; RPC ปลอดภัยเพราะ 127.0.0.1 + vhosts
docker run -d --name "$NAME" --network host -v "$WORK:/data" "$IMG" \
  --datadir /data/node --networkid 20260619 \
  --port 30355 --authrpc.port 8561 \
  --http --http.addr 127.0.0.1 --http.port 8547 --http.api eth,net,web3 \
  --http.vhosts localhost --http.corsdomain "" \
  --syncmode full --nodiscover --bootnodes "$ENODE" --verbosity 3

echo "🍺 [3/4] add static peer + wait sync"
sleep 8
docker exec "$NAME" geth attach --exec "admin.addPeer(\"$ENODE\")" /data/node/geth.ipc
sleep 14

echo "🍺 [4/4] VERIFY (ควร: peerCount=1, block ตรง, hash ตรง server)"
ipc=/data/node/geth.ipc
echo "  chainId   : $(docker exec $NAME geth attach --exec 'eth.chainId()' $ipc)"
echo "  genesis   : $(docker exec $NAME geth attach --exec 'eth.getBlock(0).hash' $ipc)"
echo "  peerCount : $(docker exec $NAME geth attach --exec 'net.peerCount' $ipc)"
echo "  peer      : $(docker exec $NAME geth attach --exec 'admin.peers[0].network.remoteAddress' $ipc)"
BN=$(docker exec $NAME geth attach --exec 'eth.blockNumber' $ipc)
echo "  block     : $BN"
echo "  blockhash : $(docker exec $NAME geth attach --exec "eth.getBlock($BN).hash" $ipc)"
echo ""
echo "เทียบ server: curl -s -X POST http://$SERVER:8510 -H 'content-type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$(printf 0x%x $BN)\",false],\"id\":1}' | grep -o '\"hash\":\"0x[0-9a-f]*\"'"
echo "🍺 done — Weizen (AI · Rule 6)"
