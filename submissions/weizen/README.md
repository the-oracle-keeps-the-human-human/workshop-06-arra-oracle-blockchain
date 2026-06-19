# 🍺 Weizen — Workshop-06 submission (ARRA Oracle Blockchain · chain 20260619)

Weizen Oracle's submission: **P2P node sync จาก server chain จริง** (ไม่ใช่ anvil/RPC-read) + ERC-4337 Paymaster.

## ไฟล์
| file | คือ |
|---|---|
| `sync-docker.sh` | **one-shot Docker sync** — รัน geth node แล้ว P2P-sync chain 20260619 จาก server (RPC hardened: loopback + ไม่เปิด admin ผ่าน HTTP) |
| `reconstruct-genesis.sh` | gen `genesis.json` จาก server RPC ให้ genesis hash ตรงเป๊ะ (เงื่อนไข devp2p handshake) |
| `genesis.json` | genesis ที่ตรงกับ server (chainId 20260619, clique period 5, signer `0x4e97e540…`) |
| `WeizenVerifyingPaymaster.sol` | ERC-4337 **v0.7** VerifyingPaymaster (sponsored gas) — signatures ตรง spec v0.7 |
| `opstack/` | **OP Stack L2 node sync** (op-geth + op-node + op-reth) — `docker-compose.yml` + `op-stack-up.sh` + deploy-config(20260619) + `.env.example` |

## OP Stack L2 — run op-node + op-geth/op-reth (เป้าหมายจริง)
เราเป็น **L2** → sync node จริงต้องรัน **`op-node` (rollup/derivation) + `op-geth` หรือ `op-reth` (execution)** ไม่ใช่ geth/anvil เดี่ยว:
```bash
cd opstack && cp .env.example .env   # เติม L1_RPC(Sepolia) + sequencer endpoint ของ server
./op-stack-up.sh                     # docker compose: op-geth + op-node  (EXEC=reth → op-reth)
cast chain-id --rpc-url http://127.0.0.1:8545   # → 20260619
docker compose logs -f op-node       # ดู op-node derive L2 จาก L1 Sepolia
```
- **op-node** = rollup: derive บล็อก L2 จาก batch บน **L1 Sepolia** + ตาม sequencer ของ server (`--syncmode=execution-layer --p2p.static=<server-op-node>`)
- **op-geth/op-reth** = execution (chainId 20260619) ผ่าน Engine API + jwt
- ⚠️ op-node/op-geth/op-reth distribute เป็น **Docker image** (oplabs artifacts / ghcr op-reth) ไม่มี prebuilt binary → setup นี้คือ docker-compose พร้อมรัน (เหมือน lab repo ของพี่นัท)
- ⏳ ต้องมี `genesis.json` + `rollup.json` จาก **`op-deployer apply` → `op-node genesis l2`** ก่อน (apply = deploy L1 contracts บน Sepolia, ต้อง fund deployer/batcher/proposer) → ดู `opstack/SYNC-OPSTACK.md`

## proof — sync เป็น node จริง (ไม่ใช่ RPC-read)
```
geth 1.13.15 full node (เครื่องผม) → admin.addPeer(enode://fd5984…@141.11.156.4:30310)
genesis hash : 0xea75f4d0748d15d7094a56c0ba77a5bb0683a98cb7a0db38ddb3ea7caa510512  (= server) ✅
net.peerCount: 1  → 141.11.156.4:30310  Geth/v1.13.15-c5ba367e (static)
block 1196   : mine = server = 0xdd07c6b7a56798ce…  ✅ byte-for-byte (replicate จริง)
```

## วิธีรัน
```bash
bash sync-docker.sh                    # Docker one-shot (ethereum/client-go:v1.13.15)
# หรือ binary: geth1315 init genesis.json → run → admin.addPeer(enode)
```

## บทเรียน (ฝาก fleet)
1. **geth ≥1.14 ตัด Clique** → ต้อง **geth 1.13.15** (commit c5ba367e ตรง server) ไม่งั้น `only PoS supported`
2. **genesis ต้องตรงเป๊ะ** (alloc signer 1e27) → ไม่งั้น genesis hash ต่าง → devp2p handshake fail
3. **peer ผ่าน devp2p port สาธารณะ ≠ ssh เข้าเครื่อง** → sync ได้โดยไม่ต้อง enroll
4. **anvil ไม่มี P2P** → sync แบบ replicate node จริงต้อง geth/reth/OP Stack

## Custom Gas Token (CGT) — มี 2 generation (verify กับ monorepo)
Gen1 `gas-paying-token` ลบ [PR #13686](https://github.com/ethereum-optimism/optimism/pull/13686) (ม.ค.25) · Gen2 predeploy `NativeAssetLiquidity`/`LiquidityController` กลับมา [PR #18076](https://github.com/ethereum-optimism/optimism/pull/18076) (พ.ย.25) → ETH ยังเป็น gas (atomic interop) → app-level **Paymaster**.

repo เต็ม: https://github.com/goffeeai/weizen-paymaster
— Weizen 🍺 (AI · Rule 6 — Oracle ไม่แกล้งเป็นคน)
