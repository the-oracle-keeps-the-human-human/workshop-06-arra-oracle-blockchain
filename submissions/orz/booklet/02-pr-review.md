## §2 cross-PR review — L1-vs-L2 ที่ปนเปกัน

**5 PR review. ตัวเดียวที่เป็น L2 OP Stack จริง.** 3 PR ที่เคลม L2 จริงๆ คือ L1 Clique pretending. 1 PR ที่ honest บอกว่า "L1 now, L2 pending"

### Nova #14 — sequencer จริงตัวเดียว

deploy 4 L1 contract บน Sepolia จริง (verify บน Etherscan):

```
OptimismPortalProxy          0xcDAd5Bf85455DA5b3EfF8fFef1f8Ba5cc49d7011
SystemConfigProxy            0xd4645B54EC1192b11d348Ffcb1008d87A4C64C59
L1CrossDomainMessengerProxy  0xFB543275962265EA73B70B8C44e8140994714308
L1StandardBridgeProxy        0xDE29180bc15627AF9D8502CA3e6E06A769856811
DisputeGameFactoryProxy      0x3E5c2BfcA48aD45826129b4e66190B9b5F58E3bd
L1 start block               11092765
```

L2 genesis `0xd5fff5…ac2d`, block 1727+ producing, op-geth v1.101702.2 + op-node v0.0.0-dev. การ deploy นี้ stake รวมเกือบ 1 Sepolia ETH สำหรับ proxy + dispute. ไม่มีคนอื่นทำ — เพราะ stake จริง

### Weizen #10 — Paymaster pair กับ Orz

ทั้ง Weizen และ Orz เลือก **ERC-4337 v0.7 VerifyingPaymaster** อิสระจากกัน → ลงตัวที่คำตอบเดียวกัน — น่าสนใจ

```
                       Weizen #10            Orz #13
EntryPoint version     v0.7 ✅               v0.7 ✅
EntryPoint addr        canonical             0x0000000071727De22E5E9d8BAf0edAc6f37da032
L1 target              Sepolia (pending)     Sepolia (pending)
signer model           off-chain ECDSA       off-chain ECDSA
API layer              (not in PR body)      Fastify :8642 POST /sponsor
```

**ที่ต้อง diff**: getHash binding ของแต่ละตัวต้อง bind `chainid + paymaster + sender + window` เป็นอย่างน้อย ขาดอันใดอันหนึ่ง → cross-chain หรือ cross-paymaster replay vector

Weizen sync proof real: `genesis 0xea75f4d0…510512` = server port 8512, peer count 1, block 1196 byte-for-byte match. **ส่วน L2 sync part incomplete** — P2P ปิด → ติด block 0 เหมือน Vessel

### Vessel #9 — target ผิด stack

15,970 บรรทัด — biggest PR. ตั้งชื่อ "Chain 20260619 sync script + docker-compose" บ่งบอก L2. แต่ของจริง: docker-compose target Clique L1 (signer `0x0C849857…`, bootnode `enode://977e58…@141.11.156.4:30303` = server port 8545) **ไม่ใช่ Nova OP Stack**

architectural mismatch ที่ไม่สามารถแก้ด้วย flag เพราะ:

- Vessel's genesis = `0xedf353…` (Clique cluster)
- Nova's L2 genesis = `0xd5fff5…ac2d` (OP Stack rollup config)
- → handshake fail forever, ไม่ว่าจะเปิด P2P หรือไม่

**ทางออก**: rename เป็น "L1 Clique sync" — ของจริงที่ pivot ทำงานได้ — หรือ rewrite ใช้ Nova's `rollup.json` + op-node + op-geth

### Bongbaeng #7 — cleanest

3 ไฟล์ 87 บรรทัด. proof: peers=1, block 1178→1181 climbing, `genesis edf353` match server. ระบุปัญหา "6 genesis ต่างกัน" ใน PR body — เห็น fragmentation เหมือนกัน ตอน Orz เห็น 9 (probe ครอบคลุมกว่า). **independent observations converging on the same diagnosis**

### Chaiklang #2 — 3rd genesis cluster

genesis `0xb27b68…` — เป็น cluster ที่สามใน audit ของ Orz (แยกจาก `0xedf353` กับ Nova's `0xd5fff5`). enode `141.11.156.4:30313` peer 0→54 ใน ~16s. **honesty bar**: "L1 Clique now, OP Stack L2 on Sepolia pending funding" — ฉลากที่ตรงกับ Weizen #10 + Orz #13

### meta pattern

3 sync PR (#2 #7 #10) ต่างคนต่าง cluster — confirm audit ของ Orz. 1 PR (#9 Vessel) target ผิด stack — ลงโทรม่าน "L2" แต่อยู่ใน L1 หนา. 1 PR (#14 Nova) คือ L2 OP Stack จริง — แต่ genesis ของ Nova ก็ไม่ match กับ sync PR ตัวไหนเลย. 1 PR (#13 Orz) จงใจไม่แตะ stack L2 ที่ fragmented — deploy L1 Sepolia public testnet + Paymaster ของจริง

ขาด canonical genesis = ขาด federation. ทุก PR กระทำงานในระดับของแต่ละคน, ไม่มีตัวเชื่อม. **มันคือคำว่า "ขึ้น chain ร่วมกัน" ที่ไม่มี chain ร่วมกันเลย** จนกว่าจะตกลง genesis เดียว
