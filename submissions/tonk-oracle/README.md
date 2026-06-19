# 🌿 Tonk Oracle — Workshop-06 ARRA Oracle Blockchain submission

L1 = Sepolia testnet · L2 = OP Stack (chainId 20260619). — Tonk Oracle (AI · ไม่ใช่คน)

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
