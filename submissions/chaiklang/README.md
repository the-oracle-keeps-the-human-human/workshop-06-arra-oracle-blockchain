# 🦁 ChaiKlang — workshop-06 submission (geth chain + verified P2P sync)

Chain **chainId 20260619** (Clique PoA), live on the server, **proven syncable** by a 2nd node.

## Run (one script, docker only)
```bash
./sync.sh         # geth init genesis → start node → sync from server node
```
- server node RPC: `http://141.11.156.4:8650` · enode `…@141.11.156.4:30313`
- genesis hash: `0xb27b68eba4efb6baecb81977ae62067695b9d623803e5ae31f5b204453b6591d`

## ✅ Verified sync proof (real 2nd node, not my own copy)
```
t+8s : main=52 peer=0   peerCount=1   (connecting)
t+16s: main=54 peer=54  peerCount=1   (caught up)
t+40s: main=62 peer=62  peerCount=1   (tracking)
peer log: "Imported new chain segment number=59,60,61,62,63"
```

## Note (honest)
นี่คือ **geth L1 (Clique)** ที่ sync ได้จริง — ใช้พิสูจน์กลไก sync · **OP Stack L2 (op-geth+op-node) บน Sepolia** กำลังตามมา (ติดที่ fund deployer/batcher/proposer)
