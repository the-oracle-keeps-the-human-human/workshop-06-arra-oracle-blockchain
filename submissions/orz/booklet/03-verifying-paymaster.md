## §3 🔧 VerifyingPaymaster — digest binding + libp2p vs devp2p

**กฎที่หนึ่ง: digest ต้อง bind chain. กฎที่สอง: rollup-layer P2P ไม่ใช่ EL devp2p.** ทุกอย่างหลังจากนั้นเป็น optimization

### why VerifyingPaymaster (ไม่ใช่ TokenPaymaster)

ERC-4337 มีหลาย Paymaster pattern: VerifyingPaymaster (off-chain signer), TokenPaymaster (ERC-20 ของ gas), PimlicoPaymaster (account abstraction infra-as-a-service). Orz เลือก VerifyingPaymaster เพราะ 3 เหตุผล:

1. **off-chain signing = policy in code, not token economics.** signer EOA หนึ่งตัว + allowlist ใน API server. แก้นโยบาย = redeploy API ไม่ใช่ redeploy contract
2. **TokenPaymaster ต้อง token + price oracle + AMM liquidity** = อีก 3 failure mode ก่อน userOp แรกถูก sponsor. ราคา oracle ผิดพลาด → liquidate. AMM liquidity drain → ไม่มี token แลก gas
3. **โจทย์ workshop คือ "deploy L1 Sepolia ของจริง"** — VerifyingPaymaster ใช้ 1 contract + 1 signer + EntryPoint stake. ทางตรงที่สุด

### digest binding (the gate)

`OrzVerifyingPaymaster.getHash` bind **11 fields** เข้า digest:

```solidity
function getHash(
    PackedUserOperation calldata userOp,
    uint48 validUntil,
    uint48 validAfter
) public view returns (bytes32) {
    return keccak256(abi.encode(
        DOMAIN_TAG,                       // "OrzVerifyingPaymaster.v1"
        block.chainid,                    // ป้องกัน cross-chain replay
        address(this),                    // ป้องกัน cross-paymaster replay
        userOp.getSender(),               // ป้องกัน sender-substitution
        userOp.nonce,
        keccak256(userOp.callData),
        userOp.accountGasLimits,
        userOp.preVerificationGas,
        userOp.gasFees,
        validUntil,
        validAfter
    ));
}
```

ขาด `chainid` → replay จาก testnet ไป mainnet. ขาด `paymaster addr` → replay ระหว่าง paymaster ที่ใช้ signer ตัวเดียวกัน. ขาด `sender` → upstream API ที่ sign แล้วถูก swap sender ก่อนส่ง bundler

### paymasterAndData layout (ERC-4337 v0.7)

EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) แยก `paymasterAndData` เป็น:

```
[0..20]    paymaster address      (20 bytes)
[20..36]   verificationGasLimit   (uint128)
[36..52]   postOpGasLimit         (uint128)
[52..]     PAYMASTER_DATA_OFFSET — paymaster อ่านได้
```

OrzVerifyingPaymaster อ่าน tail หลัง offset 52:

```
[0..6]     validUntil  (uint48)   = 6 bytes
[6..12]    validAfter  (uint48)   = 6 bytes
[12..77]   ECDSA signature        = 65 bytes
total tail = 77 bytes — enforce exactly
```

ถ้า tail length ≠ 77 → revert `InvalidPaymasterDataLength`. **fixed-length frame = ลด attack surface**

### libp2p ≠ devp2p (ตัวบล็อกที่ทำให้ Vessel/Weizen ติด block 0)

OP Stack แยก L2 ออกเป็น 2 layer:

| layer | client | P2P stack | role |
|---|---|---|---|
| Consensus (CL) | op-node | libp2p (multiaddr) | block propagation + L1 derivation |
| Execution (EL) | op-geth | devp2p (enode) | state sync, transaction mempool |

CL → EL ใช้ **engine API** (`engine_newPayloadV3`, `engine_forkchoiceUpdatedV3`) — JSON-RPC over auth-jwt. **op-geth รับ L2 block จาก op-node ผ่าน engine API เท่านั้น** — devp2p ของ geth ใช้ state-sync จาก peer op-geth อื่นได้แต่ไม่ใช่ source of truth

ดังนั้น `--nodiscover` / `--maxpeers 0` ใน op-geth = irrelevant ต่อ L2 sync. แค่ตัด ETH mainnet devp2p ที่ไม่ได้ใช้อยู่แล้ว. **ตัวบล็อกจริง** = `--p2p.disable` ใน **op-node** (CL) — ตัด libp2p ระหว่าง op-node ของแต่ละ Oracle

### static-peer Nova — libp2p multiaddr, not enode

flag ที่ Vessel/Weizen/Atom ต้อง:

```
op-node:
  REMOVE: --p2p.disable
  ADD:    --p2p.static=/ip4/141.11.156.4/tcp/<nova_p2p_port>/p2p/<nova_peer_id>
  ADD:    --p2p.listen.tcp=<unique_port_per_oracle>   # Atom port collision fix
  ADD:    --l1=<sepolia_rpc>                          # derivation fallback
```

`<nova_peer_id>` ต้อง derive จาก Nova's libp2p private key (Base58 encoded). enode URL (geth devp2p) ใช้ไม่ได้ — wire format ต่าง

### sync paths รวม (forecast)

OP Stack มี 2 sync paths:

```
1. P2P (unsafe blocks)   op-node ↔ op-node ผ่าน libp2p
                          → fast path, ไม่ canonical
                          → ใช้ระหว่าง Nova ยัง batch L1 ไม่ได้

2. L1 derivation (safe)   op-node อ่าน batch tx จาก L1 (Sepolia)
                          → canonical, ไม่ต้องการ peer-to-peer
                          → Nova ต้อง deposit + post batch ที่ SystemConfig
                          → cost ETH ต่อ batch
```

ตอนนี้ Nova ยัง batch ไม่ได้ → path 2 ปิด → ทุกคนต้องใช้ path 1 → ต้อง libp2p static-peer ของ Nova. **เมื่อ Nova batch L1 → path 1 กลายเป็น optimization** — ทุกคน sync ผ่าน L1 derivation ได้โดยไม่รู้ libp2p ของ Nova

### Orz's deliberate side-step

PR #13 ไม่แตะ stack L2 เลย — deploy L1 Sepolia direct ที่ EntryPoint v0.7 canonical. ไม่ต้องการ static-peer ของใคร ไม่ต้องการ shared genesis. **federation ที่ใช้ Sepolia public testnet มีอยู่แล้วฟรี** — ตัวเลือกที่ trade off "L2 throughput" กับ "deploy ของจริงในวันนี้"
