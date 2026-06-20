# 🌿 Tonk Oracle — Workshop-06 ARRA Oracle Blockchain submission

L1 = Sepolia testnet · L2 = OP Stack (chainId 20260619). — Tonk Oracle (AI · ไม่ใช่คน)

## 🔄 อัปเดต 2026-06-20 (session 2) — ปิด blocker "needs go toolchain"

session ก่อน (PR #12) เขียนไว้ว่า OP-Stack L2 follower *"ยังไม่ได้ทำ — needs go toolchain"*
วันนี้ปิดรูนั้นแล้ว **โดยไม่แตะ root ไม่ใช้ docker**:

- ✅ **build op-geth 1.101702.2 + op-node v1.19.0 จาก source** (โหลด Go ลง home-dir, ~90s) → [`op-stack-follower/`](op-stack-follower/)
- ✅ รัน follower → op-geth init + op-node derivation framework เดินได้จริง
- 🐛 เจอ + แก้ **2 บั๊กจริง** (รายละเอียด [`op-stack-follower/BUILD.md`](op-stack-follower/BUILD.md)):
  - **A:** `sync.sh` ส่ง `--verbosity` ทำ op-node v1.19.0 crash → แก้เป็น `--log.level`
  - **B:** ground-truth: `:8181` genesis.json (`f26a66df`) ≠ rollup.json (`e365a0cf`) ≠ Nova live (`0x1c9445c6`) → follower sync ไม่ได้จนกว่า Nova re-publish
- ✅ **`sync-fixed.sh`** มี genesis-consistency guard → **abort เองถ้า genesis ผิด = เคลม proof ปลอมไม่ได้**
- 📖 **booklet เต็ม** ตามที่พี่นัทสั่ง: [`booklet/ws06-booklet.md`](booklet/ws06-booklet.md)
- ⛔ **head-match proof จริง**: ยังติด blocker ฝั่ง Nova (stale publish) — staged พร้อมยิงทันทีที่ chain นิ่ง · **ไม่เคลมจนกว่าจะเกิดจริง**

*(ของเดิมด้านล่างคงไว้ตามจริง — Nothing is Deleted)*

## สถานะ (honest — แยก "ทำแล้ว" vs "ยังไม่ได้ทำ")

### ✅ ทำแล้ว + verify จริง
- **Paymaster (ERC-4337) บน Sepolia** → repo [tonkmac/tonk-paymaster-sepolia](https://github.com/tonkmac/tonk-paymaster-sepolia)
  - viem + permissionless.js · sponsored UserOp → `FloodBoyDemo` `0x85BB3F44351BC59FeA7a3B9EF41e671F0D2Fc546`
  - Dockerfile + CI→ghcr · frontend live: `http://141.11.156.4:8696`
- **Dev chain (anvil, chainId 20260619)** + explorer → repo [tonkmac/tonk-arra-chain](https://github.com/tonkmac/tonk-arra-chain)
  - RPC `http://141.11.156.4:28545` · explorer `http://141.11.156.4:25100` (viem live read)
- **Research** (โพสต์ใน discussion #1): OP Stack custom-gas-token spec (deprecated) → Paymaster · reth supports `ots_` (Otterscan)

### ⏳ ยังไม่ได้ทำ (ตรงไปตรงมา)
- **OP Stack L2 จริง (op-node + op-geth + op-batcher + op-proposer)** — ยังไม่ได้ build
  - blockers: server ไม่มี go/op-stack toolchain · funding (pool PK ผมไม่มี) · ยังไม่ตกลง canonical-deployer
- **Cross-node sync proof** — ลอง geth + bootnode No.10X แล้วติด shared-account (port 8551 collision, datadir lock) → ไม่มี proof สำเร็จ

## `arra-sync.sh` — docker sync script (unverified by author)
sync เข้า chain (chainId 20260619) ผ่าน docker geth + bootnode · **honest: ผมไม่มี docker เลย verify เองไม่ได้** — docker isolation จะแก้ port-collision ที่ผมติด bare-metal · ใครมี docker รัน + ดู PROOF (peers + block) ท้าย script ได้

## แผน OP Stack L2 (เมื่อ funded + designated)
```
1. ลง go + op-stack (op-deployer/contracts-bedrock, op-geth, op-node)
2. deploy L1 contracts บน Sepolia (OptimismPortal/SystemConfig/DisputeGame) — ต้องการ funding
3. op-node genesis l2 → genesis L2 (chainId 20260619)
4. รัน sequencer: op-geth + op-node + op-batcher + op-proposer
5. sync node: op-geth + op-node ชี้ L1 + sequencer P2P → docker script ให้เพื่อน
```
ต้องเป็น **canonical L2 1 ตัว** (ไม่ใช่ 11 oracle deploy แยก = 11 rollup)
