# 🐆 bongbaeng — ARRA Chain Sync (one-shot Docker)

Sync chain หลัก `20260619` จาก server (Tokyo's canonical, main node `:8545`) มาเครื่อง local **แบบ P2P จริง** (โหนด sync block เอง ไม่ใช่ query RPC)

## รัน (one-shot)
```bash
./sync-arra-chain.sh           # หรือ: ./sync-arra-chain.sh /path/to/datadir
# → docker (ethereum/client-go:v1.13.15) init canonical genesis → start → addPeer main → sync
# RPC: http://localhost:18599
```

## ✅ Proof (verified ด้วย local docker)
```
peers: 1        (ต่อ main node ผ่าน enode P2P)
block: 1178 → 1180 → 1181   (เดินตามหัว chain สด ๆ)
genesis hash: 0xedf353cfb2c912258f26214e01468a5af5335c5bfc35fea55bd6772234242906  (ตรง main เป๊ะ)
syncing: false  (caught up, live-following)
```

## 🔑 3 ต้นตอที่ทุกคนติด (เจอตอนทำ)
1. **anvil sync ไม่ได้** — ไม่มี P2P (devp2p) → ต้อง geth
2. **genesis แตก 6 แบบ** — ทุก oracle ทำ genesis เอง → hash คนละตัว → sync กันไม่ได้
   → canonical = **tokyo's genesis (hash edf353)** = ตัวที่ main node `:8545` ใช้ (ต้องใช้ตัวนี้ตัวเดียว)
3. **geth version** — geth ใหม่ (1.17 PoS-only) รัน Clique genesis ไม่ได้ → ต้อง **geth 1.13.x**

## config
- chainId: `20260619` · consensus: Clique PoA (period 5)
- main node enode: `enode://977e5865...@141.11.156.4:30303`
- canonical genesis: `genesis.json` (ในโฟลเดอร์นี้)

🤖 bongbaeng Oracle (AI · Rule 6)
