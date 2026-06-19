#!/usr/bin/env bash
# reconstruct genesis.json จาก server RPC ของ geth Clique chain → stdout
# ให้ genesis hash ตรงเป๊ะกับ server (เงื่อนไข devp2p handshake)
# ใช้: ./reconstruct-genesis.sh http://<SERVER>:8510 > genesis.json
# requires: cast (foundry), python3
set -euo pipefail
RPC="${1:?usage: reconstruct-genesis.sh <rpc-url>}"
export PATH="$HOME/.foundry/bin:$PATH"

CFG=$(cast rpc admin_nodeInfo --rpc-url "$RPC" | python3 -c 'import sys,json;print(json.dumps(json.load(sys.stdin)["protocols"]["eth"]["config"]))')
B0=$(cast rpc eth_getBlockByNumber 0x0 false --rpc-url "$RPC")

# signer address อยู่ใน extraData (32B vanity + 20B signer + 65B seal)
EXTRA=$(echo "$B0" | python3 -c 'import sys,json;print(json.load(sys.stdin)["extraData"])')
SIGNER="0x${EXTRA:66:40}"
# alloc: signer balance ที่ block 0 (chain เหล่านี้ prefund signer; ปรับเพิ่มถ้ามี account อื่น)
BAL=$(cast balance "$SIGNER" --block 0 --rpc-url "$RPC")

python3 - "$CFG" "$B0" "$SIGNER" "$BAL" <<'PY'
import sys,json
cfg=json.loads(sys.argv[1]); b0=json.loads(sys.argv[2]); signer=sys.argv[3]; bal=sys.argv[4]
g={
  "config": cfg,
  "nonce": b0["nonce"],
  "timestamp": b0["timestamp"],
  "extraData": b0["extraData"],
  "gasLimit": b0["gasLimit"],
  "difficulty": b0["difficulty"],
  "mixHash": b0["mixHash"],
  "coinbase": b0["miner"],
  "alloc": { signer: { "balance": bal } },
}
if b0.get("baseFeePerGas"): g["baseFeePerGas"]=b0["baseFeePerGas"]
print(json.dumps(g, indent=2))
PY
