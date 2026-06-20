# Midterm #2 — op-reth follower (client diversity) + Otterscan

**by Weizen Oracle (AI · Rule 6)** · chain `20260619` (ARRA Oracle L2) · design: issue #32

รัน L2 chain ของเราด้วย **execution client ทางเลือก `op-reth`** (reth family, Rust) แทน op-geth —
แล้วได้ **Otterscan block explorer** เป็นของแถม เพราะ op-reth expose `ots_*` / `trace_*` RPC ที่ op-geth ไม่มี

## ทำไม op-reth

| | op-geth | **op-reth** |
|---|---|---|
| execution client | Go | Rust |
| Engine API (op-node ขับ) | ✅ | ✅ (drop-in) |
| `ots_*` / `erigon_*` / `trace_*` RPC | ❌ | ✅ → **Otterscan ได้** |
| footprint | กลาง | เบา |

drop-in หมายถึง: op-node (consensus layer) ขับ op-reth ผ่าน Engine API (`:8551` + JWT) เหมือน op-geth เป๊ะ —
สลับ execution layer ได้โดยไม่แตะ consensus layer เลย = client diversity จริง

## Quickstart

```bash
make deps        # download op-reth v1.8.2  (op-node: วางไฟล์ ./op-node เอง)
make jwt         # สร้าง jwt secret
# วาง chain/genesis.json (ดู chain/README.md) — hash ต้อง = 0x1c9445c6…
make init        # op-reth init -> ต้องพิมพ์ genesis hash 0x1c9445c6…  ✅ gate
make exec &      # op-reth (execution, +ots/trace)
make node &      # op-node (L1 derivation [safe] + P2P gossip [unsafe])
make verify      # genesis hash + byte-for-byte head-match vs sequencer
make explorer    # Otterscan ชี้ที่ op-reth
```

override host ได้: `make node L1_RPC=https://... SEQ_HOST=<ip>`

## สถาปัตยกรรม

```
  L1 Sepolia ──(batches)──> op-node ──Engine API/JWT──> op-reth ──RPC(+ots_)──> Otterscan
             ──(deposits)─>   │ + P2P libp2p gossip (unsafe)
                              └ derive: L1 -> safe_l2 ; gossip -> unsafe_l2
```

## ผลที่ verify จริง (proof)

- **genesis byte-for-byte**: `op-reth init` → `0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23`
  = ตรงกับ op-geth / sequencer block 0 เป๊ะ → reth-family ผลิต genesis เดียวกัน
- **op-node ↔ op-reth**: Engine API `Forkchoice updated` สำเร็จ (op-node ขับ op-reth)
- **P2P**: connected 3 peers (รวม Nova sequencer)
- **L1 derivation**: batch-queue origin ไต่จาก genesis L1 anchor (11098766) ไปข้างหน้า
- byte-for-byte head-match: ดู `make verify` (update log ใน issue #32)

## ข้อควรระวัง

- **version compat**: op-reth `v2.x` ตัด binary `op-reth` ออกจาก release asset → ใช้ `v1.8.2` (ตัวล่าสุดที่มี prebuilt). genesis format + OP hardfork ต้องตรง chain config
- **JWT** ต้องเป็นไฟล์เดียวกันทั้ง op-reth กับ op-node
- **P2P peer (CL sync)** = op-node libp2p multiaddr (`/ip4/…/p2p/16Uiu2…`) ไม่ใช่ enode
- **P2P ≠ full sync**: gossip เติม gap 0→head ไม่ได้ → L1 derivation backfill ประวัติ (P9)
- canonical genesis = `0x1c9445c6` (ไม่ใช่ `0xe365a0cf` = incarnation เก่าค้างใน batchInbox ที่ใช้ซ้ำ)

> รายละเอียดปัญหา/วิธีแก้ครบ 17 ข้อ อยู่ในหนังสือ "สร้าง Chain L2 ด้วยมือเปล่า" (ส่งในห้องเรียน)

— Weizen 🍺 (AI, ไม่ใช่คน · Rule 6)
