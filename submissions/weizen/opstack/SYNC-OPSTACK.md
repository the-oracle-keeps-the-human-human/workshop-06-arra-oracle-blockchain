# OP Stack L2 (chain 20260619) — client + วิธี sync จากเครื่องตัวเอง

> เราเป็น **L2** → ไม่ได้รัน geth/anvil เดี่ยวๆ. client ของ OP Stack L2 = **`op-geth` (execution) + `op-node` (rollup/consensus)** — ไม่ใช่ geth ธรรมดา. chain หลักรันบน server, เราเปิดโหนด sync จากเครื่องตัวเองโดยตามจาก L1 (Sepolia) + sequencer.

## สถาปัตยกรรม (ทำไม anvil/geth เดี่ยวไม่พอ)

```
L1 Sepolia (11155111) ──(batches/L2 output)── op-batcher / op-proposer
        │                                              ▲
        │ derive                                       │ (sequencer = server)
        ▼                                              │
   op-node (rollup) ───engine API (8551)───► op-geth (execution, chainId 20260619)
        │                                              │
   เปิดโหนดเพิ่ม = รัน op-node + op-geth ของเราเอง ► sync จาก L1 + sequencer ของ server
```

- **op-geth** = geth fork ที่รู้จัก L2 (deposits, L1 fee). รัน execution layer ของ chain 20260619
- **op-node** = consensus/rollup: derive บล็อก L2 จาก batch บน L1 Sepolia + ตาม sequencer (server) → ป้อนให้ op-geth ผ่าน Engine API
- "เปิดโหนดเพิ่มที่ sync" = รัน **op-geth + op-node ของเรา** ชี้ L1 = Sepolia RPC, sequencer/rollup = ของ server → sync ได้จริง (ต่างจาก anvil ที่ไม่มี derivation)

## 1) คำนวณ genesis + rollup config (chainId 20260619)

ต้อง deploy OP Stack L1 contracts ลง Sepolia ก่อน (op-deployer / bedrock) แล้วค่อยสร้าง L2 genesis:

```bash
# หลัง deploy L1 contracts บน Sepolia แล้ว (ได้ไฟล์ L1 deployments/addresses)
op-node genesis l2 \
  --deploy-config ./deploy-config.json \
  --l1-deployments ./deployments/sepolia.json \
  --outfile.l2 genesis.json \
  --outfile.rollup rollup.json \
  --l1-rpc https://ethereum-sepolia-rpc.publicnode.com
```
→ ได้ `genesis.json` (L2 state) + `rollup.json` (rollup params). แชร์ 2 ไฟล์นี้ให้ทั้ง fleet → ทุกคน sync chain เดียวกัน

## 2) เปิดโหนด sync จากเครื่องตัวเอง (chain อยู่บน server)

```bash
# (a) op-geth — execution
op-geth init --datadir=./datadir genesis.json
op-geth \
  --datadir=./datadir --networkid=20260619 \
  --http --http.port=8545 --http.api=eth,net,web3,debug,ots \
  --authrpc.addr=127.0.0.1 --authrpc.port=8551 --authrpc.jwtsecret=./jwt.txt \
  --rollup.sequencerhttp=http://<SERVER>:8547 \
  --rollup.disabletxpoolgossip=true --syncmode=full

# (b) op-node — rollup (ตาม L1 Sepolia + sequencer ของ server)
op-node \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=<sepolia-beacon-or --l1.trustrpc> \
  --l2=http://127.0.0.1:8551 --l2.jwt-secret=./jwt.txt \
  --rollup.config=./rollup.json \
  --syncmode=execution-layer --p2p.static=<server-op-node-enode>
```
→ verify: `cast chain-id --rpc-url http://127.0.0.1:8545` → `20260619` + block ตามทัน server

## 3) Paymaster (ERC-4337) — app-level บน L2

หลัง chain sync แล้ว: deploy EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) + `WeizenVerifyingPaymaster` (ดู `../src/`) ลง L2 → gasless UserOp. ETH ยังเป็น gas (custom gas token deprecated — ดู README).

---
⚠️ **honest:** full OP Stack (op-geth + op-node + batcher + proposer + L1 contracts) รันครบ = หนัก → chain หลักอยู่บน **server**. ส่วนที่ผมทำ off-server: deploy-config นี้ + deploy Paymaster ขึ้น **Sepolia** (ผ่าน RPC) + sync จากเครื่องเมื่อมี server rollup config. คำสั่ง op-geth/op-node ข้างบน = OP Stack reference pattern (ยังไม่ได้ test ครบบนเครื่องนี้เพราะรัน full stack ไม่ไหว — RAM)
— Weizen 🍺 (AI · Rule 6)
