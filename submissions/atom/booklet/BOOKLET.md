# วันที่ Oracle School แยก “รันขึ้น” ออกจาก “OP Stack L2 จริง”

> เวอร์ชันภาษาไทย เพิ่มหลัง approval จาก Axe: คงปกและดีไซน์เดิมไว้ แต่ปรับเนื้อหาในเล่มเป็นไทยเป็นหลัก พร้อมคำเทคนิคอังกฤษที่จำเป็น เช่น `op-node`, `op-geth`, `P2P`, `rollup.json`.

## Hook

Workshop 06 เริ่มจาก chain หลายแบบที่ “รันขึ้นจริง” แต่จุดเปลี่ยนคือการยอมรับว่า chain ที่รันขึ้นไม่ได้แปลว่าเป็น OP Stack L2 ที่ถูกต้องเสมอไป  Anvil, Clique และ PoA chain ช่วยให้ทีมเรียนเร็ว แต่โจทย์จริงคือ chain ที่ตั้งอยู่บน Sepolia และมี `op-node` กับ L2 execution client ทำงานคู่กัน

## 1. เป้าหมายที่ถูกต้อง

เป้าหมายที่ควรใช้เป็นกรอบคือ:

```text
L1 Sepolia contracts + rollup config
op-geth/op-reth เป็น L2 execution client
op-node เป็น rollup/consensus client
followers sync จาก canonical reference chain
```

plain geth peer หรือ `enode` อย่างเดียวไม่พอสำหรับ OP Stack L2

## 2. Reference chain

Nova PR #14 เป็น reference เพราะมีชิ้นส่วนสำคัญครบ:

```text
op-geth RPC: 8555
op-node RPC: 8655
chainId: 20260619
blocks advancing on server
rollup.json present
```

หลักฐานที่ Atom ตรวจจาก session:

```text
Nova :8555 block 0x86f
Nova op-node :8655 unsafe_l2 2159
safe_l2 0
finalized_l2 0
```

ตีความ: Nova produce `unsafe_l2` ได้แล้ว แต่ `safe_l2/finalized_l2` ยังไม่เดิน เพราะยังไม่มี batcher ที่ส่ง batch ขึ้น Sepolia ใน flow นี้

## 3. เส้นทาง sync มีสองชั้น

```text
P2P unsafe path:
  op-node <-> op-node ผ่าน libp2p
  เร็ว เห็นผลทันที แต่ยังไม่ใช่ canonical finality

L1 derivation path:
  op-node อ่าน L1 batches จาก Sepolia
  เป็นทาง canonical ของ safe blocks
  ต้องมี batch data จาก op-batcher
```

สถานะตอนนี้: เพราะยังไม่มี working batcher ส่ง L2 data ขึ้น Sepolia, follower จึงต้องใช้ P2P unsafe path เพื่อให้ block ขยับก่อน

## 4. ความเข้าใจที่ต้องแก้

mental model ที่ผิด:

```text
geth enode/devp2p จะส่ง L2 chain ให้ follower
```

mental model ที่ถูก:

```text
op-node รับหรือ derive block
op-node ส่ง payload เข้า op-geth ผ่าน Engine API
op-geth execute payload
```

ดังนั้น root cause แรกของ L2 stuck at block 0 ใน mode นี้มักไม่ใช่ `geth --nodiscover` หรือ `--maxpeers 0` แต่ควรดู `op-node --p2p.disable`, peer format, rollup config และ Engine API ก่อน

## 5. ทำไม follower ค้าง block 0

followers ที่เห็นยังค้าง block 0:

```text
Vessel :8770 block 0
Weizen :8788 block 0
Tokyo  :8780 block 0
Tinky  :8577 block 0
```

สาเหตุที่เป็นไปได้:

- `genesis.json` / `rollup.json` ไม่ใช่ชุด canonical เดียวกับ Nova
- `op-node` ปิด P2P หรือชี้ peer ผิด
- ใช้ `enode` แทน libp2p multiaddr
- follower เผลอรันเป็น sequencer
- port ชนกัน
- ยังไม่มี L1 batches จึงทำให้ `safe_l2` เป็น 0 ได้

## 6. สูตร follower ขั้นต่ำ

```text
canonical genesis.json จาก Nova
canonical rollup.json จาก Nova
local jwt.txt สำหรับ op-node + op-geth ของตัวเอง
op-geth authrpc endpoint
op-node without --sequencer.enabled
op-node with --p2p.static=<Nova libp2p multiaddr>
unique ports
```

## 7. Honest failure

ชัยชนะของ session นี้ไม่ใช่ทุกคนมี follower ที่ perfect ทันที แต่คือทั้งห้องแก้ model ร่วมกัน:

- L1 dev chain ไม่ใช่ OP Stack L2
- OP Stack L2 แยก execution client และ rollup client
- `op-node` P2P คือ libp2p ไม่ใช่ geth devp2p
- ตอนนี้ต้องพึ่ง P2P เพราะยังไม่มี batcher แต่ระยะยาว L1 derivation คือ canonical path

การแก้ model นี้คือสิ่งที่เปลี่ยน PR จาก “มัน start ได้” เป็น “มัน sync chain ที่ถูกต้อง”

## 8. Approval update

Axe approve ทิศทางดีไซน์แล้ว และขอให้ปรับเนื้อหาเป็นภาษาไทยก่อนส่ง PR  เวอร์ชันนี้จึงเพิ่มภาษาไทยเป็นหลักในเล่ม และคงหน้าปก/visual direction เดิมไว้


<p align="center"><img src="../assets/easter-egg-logo.png" width="40" alt="tiny easter egg logo"></p>

<!-- easter egg thumbnail: centered in source; rendered PDF uses rotating page corners -->
