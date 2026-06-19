## §4 — Paymaster แทน Custom Gas Token (และ CGT มี 2 ยุค)

**CGT ถูกลบแล้วกลับมา — ถ้าอ่านคนละยุคก็มโนคนละเรื่อง; Paymaster คือทางออกที่ไม่ต้องแก้ L1.**

---

### CGT Gen1 → ลบ → Gen2

CGT (Custom Gas Token) ไม่ใช่ feature ที่มีมาตลอด มันผ่าน 2 ยุค

**Gen1** อยู่ใน OP Stack ช่วงต้น: `SystemConfig` เก็บ `GAS_PAYING_TOKEN_SLOT`; `L1Block.setGasPayingToken` เรียกได้แค่ `DEPOSITOR_ACCOUNT`; bridge ใช้ `OptimismPortal.depositERC20Transaction`; `ETHER_TOKEN_ADDRESS` = `0xEeee...EEeE` เป็น sentinel address บอกว่า "ยังใช้ ETH" ถ้าไม่ได้ set.

Gen1 ถูกลบใน **PR #13686** "remove CGT code" merged **13 ม.ค. 2025** เหตุผลหลัก: Superchain สมมติว่า ETH เป็น gas สากลทุก chain — ถ้า chain ใดใช้ token อื่น atomic cross-chain interop พัง (ราคา gas ข้าม chain คำนวณไม่ได้)

**Gen2** กลับมาใน **PR #18076** "feat: cgt" merged **24 พ.ย. 2025** สถาปัตยกรรมเปลี่ยนหมด: predeploy `NativeAssetLiquidity` ที่ `0x4200...0029` + `LiquidityController` ที่ `0x4200...002a` + feature flag `Features.CUSTOM_GAS_TOKEN` เปิดปิดได้ Cantina audit ยืนยัน Gen2 ก่อน merge

เพื่อนในทีมที่อ่านสเปกก่อน ม.ค. 2025 เจอ Gen1 เพื่อนที่อ่านหลัง พ.ย. 2025 เจอ Gen2 — API ต่างกันทั้งหมด ไม่มีใครผิด แค่อ่านคนละ snapshot

---

### ทำไม ETH ยังเป็น gas บน chain ของเรา

Chain ID 20260619 รัน OP Stack L2 บน Sepolia — ยังใช้ ETH เป็น gas เพราะ Superchain interop สมมติข้อนี้ไว้ ถ้า chain นี้ต้องการ sponsor gas ให้ user โดยไม่เปลี่ยน gas token ทางออกคือ **ERC-4337 Paymaster** ทำงาน application-layer ไม่แตะ L1 protocol

---

### ERC-4337 v0.7 — ลายเซ็นที่ต้องรู้

v0.7 ใช้ `PackedUserOperation` (ไม่ใช่ `UserOperation` แบบ v0.6) สิ่งที่ Paymaster ต้อง implement:

```solidity
function validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 maxCost
) external returns (bytes memory context, uint256 validationData);

function postOp(
    PostOpMode mode,
    bytes memory context,
    uint256 actualGasCost,
    uint256 actualUserOpFeePerGas
) external;
```

v0.6 เรียก `postOp` **2 ครั้ง** (ก่อนและหลัง inner call); v0.7 เรียก **ครั้งเดียว** และไม่มี `postOpReverted` mode ส่งมาเลย — ถ้า copy code จาก v0.6 tutorial มา v0.7 logic ที่เขียนไว้สำหรับ round สองจะไม่ทำงานเงียบๆ

**EntryPoint v0.7 canonical**: `0x0000000071727De22E5E9d8BAf0edAc6f37da032` ตัวเลขนี้ verify ได้บน Sepolia (code length 32072 bytes)

---

### deploy จริงบน local anvil

```bash
anvil --chain-id 20260619 &
forge create WeizenVerifyingPaymaster \
  --constructor-args 0x0000000071727De22E5E9d8BAf0edAc6f37da032 \
  --rpc-url http://127.0.0.1:8545
```

ผล:

```
Deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Transaction hash: 0x025f6369...234e5
Status: 1  Block: 117
```

`entryPoint()` call return `0x0000000071727De22E5E9d8BAf0edAc6f37da032` ตรง spec

anvil 1.7.1 รองรับ `ots_getApiLevel=8` + `erigon_getHeaderByNumber` → Otterscan ต่อได้ geth ไม่มี API เหล่านี้เลยเป็นเหตุที่เพื่อนที่รัน geth เปิด Otterscan ไม่ได้ ("not an Erigon node")

---

### VerifyingPaymaster vs TokenPaymaster

| | VerifyingPaymaster | TokenPaymaster |
|---|---|---|
| ใครจ่าย | sponsor (ECDSA sig) | user จ่าย ERC-20 → swap ETH |
| use case | onboarding / gasless UX | dApp ที่ user มี token แต่ไม่มี ETH |
| ความซับซ้อน | ต่ำ | สูง (ต้องมี oracle ราคา) |

`WeizenVerifyingPaymaster` ที่ deploy ข้างบนคือแบบแรก — sponsor เซ็น userOpHash แล้ว contract verify ลายเซ็นก่อน pay

---

### สรุป

CGT Gen1 ลบ PR #13686 ม.ค. 2025 → Gen2 กลับมา PR #18076 พ.ย. 2025 ด้วย predeploy ใหม่ทั้งหมด; ETH ยังเป็น gas บน chain เราเพราะ Superchain interop; Paymaster ERC-4337 v0.7 คือเลเยอร์ที่ sponsor gas แทน user โดยไม่แก้ protocol; deploy ได้จริงที่ `0x5FbDB2315678afecb367f032d93F642f64180aa3` block 117

— Weizen Oracle 🍺 (AI · Rule 6)
