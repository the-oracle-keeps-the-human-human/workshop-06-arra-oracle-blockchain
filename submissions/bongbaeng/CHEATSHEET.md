# 🐆 ARRA Oracle Chain — Cheatsheet (20260619)

## รัน chain / sync (L1 Clique — ที่ทำกันวันนี้)
```bash
# ⚠️ ต้อง geth 1.13.x (geth 1.17 PoS-only รัน Clique ไม่ได้: "terminalTotalDifficulty not set")
geth-1.13.15 init --datadir d genesis.json          # ใช้ canonical genesis (hash ต้องตรง main)
geth-1.13.15 --datadir d --networkid 20260619 --syncmode full --nodiscover \
  --http --http.port <uniq> --port <uniq-p2p> --authrpc.port <uniq>   # port ว่างทุกตัว (server แออัด!)
geth attach --exec 'admin.addPeer("enode://<main>@141.11.156.4:30303")' d/geth.ipc
# verify: net.peerCount=1 + eth.blockNumber ไต่ตาม main = sync จริง
```

## one-shot docker sync
```bash
docker run --rm -v $PWD:/data ethereum/client-go:v1.13.15 init --datadir /data/cd genesis.json
docker run -d -v $PWD:/data -p 18599:8545 ethereum/client-go:v1.13.15 \
  --datadir /data/cd --networkid 20260619 --bootnodes "enode://...@141.11.156.4:30303" --syncmode full
```

## OP Stack L2 (ของจริง — ต่างจาก Clique)
```
op-geth (EL) ──Engine API (engine_newPayloadV3)── op-node (CL)   # block มาทางนี้ ไม่ใช่ geth devp2p
op-node ──libp2p── op-node ของ Nova (sequencer)                  # unsafe blocks
follower op-node:
  REMOVE --p2p.disable ; sequencer.enabled=false
  ADD    --p2p.static=/ip4/141.11.156.4/tcp/<port>/p2p/<nova_peer_id>   # libp2p multiaddr ไม่ใช่ enode!
  ADD    --l1=<sepolia_rpc>     # L1 derivation fallback (ต้องมี op-batcher post batch ก่อน)
```

## funding (Sepolia)
```bash
cast balance <addr> --rpc-url https://ethereum-sepolia-rpc.publicnode.com
cast send --rpc-url <sepolia> --private-key $POOL_KEY <to> --value <amt>ether   # key จาก env เท่านั้น
```

## troubleshoot ที่เจอจริง
| อาการ | สาเหตุ | แก้ |
|---|---|---|
| sync ไม่ได้ | genesis hash ต่าง (6 แบบในฝูง) | ใช้ canonical genesis เดียวกัน (block0 hash ตรง) |
| geth crash PoS-only | geth 1.17 ไม่รองรับ Clique | ใช้ geth 1.13.x |
| bind address in use | server แออัด 15 nodes | หา port ว่างทุกตัว (p2p/http/authrpc) |
| anvil ตายเอง | คนอื่น pkill broad | setsid + อย่า match กว้าง |
| L2 ค้าง block 0 | op-node --p2p.disable + ไม่มี L1 batch | เปิด p2p.static peer Nova |

🤖 bongbaeng Oracle (AI · Rule 6)
