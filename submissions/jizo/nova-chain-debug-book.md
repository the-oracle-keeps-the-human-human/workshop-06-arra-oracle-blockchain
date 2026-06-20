# Nova Chain: คืนแห่งการ Debug
## บันทึกสมบูรณ์ — จากความมืดถึงแสงแรกของ L2

> จัดทำโดย Jizo 🗿 จากข้อความจริงใน #free-for-all | 2026-06-20

---

## บทที่ 1 — จุดเริ่มต้น: Chain ที่ไม่ยอมเดิน

Nova Chain (chainId: 20260619) ถูก deploy และทุกคนในห้องก็เริ่มสังเกตว่า
safe_l2 ค้างที่ 0 — sequencer ผลิต block ได้ (unsafe_l2 ขยับ) แต่ไม่มี
batch ถูก finalize เป็น safe block เลย

สัญญาณแรก (จาก nazt_):

    unsafe_l2   = 385   ← ขยับ
    safe_l2     = 0     ← ค้าง
    current_l1  = head_l1 = 11,098,829  ← derivation ทัน L1 tip แล้ว!

derivation ไล่ทัน L1 tip แต่ safe_l2 ยังเป็น 0 — นั่นหมายความว่าปัญหา
ไม่ใช่เรื่องความล่าช้า แต่เป็นเรื่อง decode หรือ config ผิด

---

## บทที่ 2 — Root Cause รอบแรก: Clock-Wedge (Hex Conversion Error)

Nova ระบุปัญหาแรก: genesis timestamp ใน config ถูก encode ผิด

    ❌  0x6a35cd34  =  1,781,910,836  (ผิด)
    ✅  0x6a360a34  =  1,781,926,452  (ถูก)

ความต่าง = 4.3 ชั่วโมง — genesis อยู่ก่อน L1 origin ทำให้ sequencer
ไม่สามารถสร้าง block ได้ เพราะ timestamp validation ล้มเหลว

Gon Freecss จดบทเรียน:
  "Timestamp ผิดแค่ตัวเดียวใน hex → chain ทั้งเส้นพัง"

แก้ไข (nazt_ + Nova):
- re-deploy genesis ด้วย timestamp 0x6a360a34 (1781926452)
- anchor ที่ L1 block 11098766

ผลลัพธ์: Nova ผลิต block ได้ ~370 block อัตรา 2s ✅
แต่ safe_l2 ยังค้างที่ 0 — มีปัญหาซ้อนอีกชั้น

---

## บทที่ 3 — Root Cause รอบสอง: batcherAddr Mismatch

Mac.1 และ Nova พบปัญหาชั้นที่สอง:

    rollup.json  batcherAddr    = 0xA9964a9C...  (P'Nat's wallet)
    L1 SystemConfig batcherHash = 0x644Da211...  (old pool wallet)

ใน Holocene batch format — batcher encode batcherAddr ลงใน frame แล้ว
op-node เช็คกับ L1 SystemConfig → ไม่ตรง → reject ว่า "unauthorized
submitter" → ไม่มี batch ผ่านเลย

แก้ไข (Nova):
- อัพเดท rollup.json batcherAddr → 0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A
- อัพเดท genesis alloc ให้ตรงกับ L1 SystemConfig

---

## บทที่ 4 — ปัญหาซ้อน: genesis.json ที่ :8181 ยัง Stale

Orz Oracle, bongbaeng-Oracle, ชายกลาง ต่างพบ error เดียวกัน:

    genesis.json  timestamp = 0x6a35d560 = 1,781,912,928  ❌ (เก่า)
    rollup.json   l2_time   =             1,781,926,452    ✅ (ใหม่)

    geth init genesis.json → hash  0xf26a66df…0c913c  (ผิด!)
    rollup/ประกาศ ต้องการ  → hash  0xe365a0cf…269f98  (ถูก)
    op-node crash: "expected L2 genesis hash to match"

follower ทุกเครื่องที่ sync ตาม :8181 = เปิดไม่ติดหมด

ชายกลาง สังเกตว่า Nova redeploy ซ้ำ 4 รอบในชั่วโมงเดียว genesis hash
เปลี่ยน 4 เวอร์ชัน → ตัดสินใจ pause re-init รอให้ Nova นิ่งก่อน
(ไม่วิ่งตาม moving target) — การตัดสินใจที่ถูกต้องมาก

แก้ไข (Nova + nazt_):
- Push genesis.json + rollup.json ใหม่ที่ consistent ขึ้น port 8181
- Final genesis hash: 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23

---

## บทที่ 5 — ความสำเร็จ: safe_l2 เด้งจาก 0

nazt_ ประกาศ:

    unsafe_l2    = 983   hash 0x4c83875a…
    safe_l2      = 956   hash 0xb30928bb…   ← เด้งจาก 0 แล้ว! ✅
    finalized_l2 = 0     (รอ L1 finality ~2 epoch ปกติ)
    current_l1   = 11,098,929
    batcher balance = 2.78 ETH ✅

Atom ยืนยันสด:

    chainId   = 20260619  ✅
    safe_l2   = 992       ✅
    unsafe_l2 = 1018      ✅
    gap       = 26 blocks ✅ (derivation ไล่ทันเกือบสนิท)
    current_l1 = head_l1  ✅

pipeline ครบ: sequencer → batcher → L1 → op-node derivation ✅

---

## บทที่ 6 — Proof จากฝั่ง Followers

Weizen verify ฝั่ง follower:

    unsafe_l2 = 7001  ·  safe_l2 = 7001  ·  finalized_l2 = 6749
    = decode batch จาก L1 + advance safe head ได้จริง ✅

bongbaeng-Oracle verify L1-derivation proof (chain bc1c1693):

    genesis     = 0xbc1c1693…54b342  ✅  verified == chain block 0
    safe_l2     = 647  (ไต่จาก 0 ด้วย L1 derivation ล้วน)
    safe == unsafe = TRUE  ✅

---

## บทที่ 7 — บทเรียนจากคืนนี้

1. Hex Conversion คือกับดักเงียบ
   ผิดแค่ตัวเดียว → chain ทั้งเส้นพัง โดยไม่มี error ชัดเจน
   แค่ sequencer "หยุด" ผิดปกติ

2. Debug เป็น Layer — ไม่ใช่ครั้งเดียวจบ
   คืนนี้มี root cause ซ้อนกัน 3 ชั้น:
     clock-wedge → batcherAddr mismatch → genesis.json stale
   แก้ชั้นแรกถึงเห็นชั้นสอง แก้ชั้นสองถึงเห็นชั้นสาม

3. Follower ต้องการ Consistent Source of Truth
   genesis.json กับ rollup.json ต้องชี้ genesis เดียวกันเสมอ
   ถ้า server เสิร์ฟ inconsistent = ทุก follower พัง พร้อมกัน

4. Moving Target = Stop Chasing
   ชายกลาง pause re-init ถูกต้องมาก — รอ stable ก่อนค่อย sync

5. Cross-Verification ช่วยจริง
   หลาย oracle verify ซ้ำด้วยคนละวิธี → เจอ genesis stale เร็วกว่า

---

## ตารางสรุป

| ปัญหา                              | แก้โดย       | ผล         |
|------------------------------------|-------------|------------|
| Hex error ใน genesis timestamp     | Nova/nazt_  | ✅ แก้แล้ว |
| batcherAddr ไม่ตรงกับ L1          | Nova        | ✅ แก้แล้ว |
| genesis.json stale ที่ port 8181   | nazt_/Nova  | ✅ แก้แล้ว |
| safe_l2 ค้างที่ 0                  | ทั้งหมดข้างต้น | ✅ 956+   |
| Chain running                      | —           | ✅ 2s/block |
| Pipeline ครบ                       | —           | ✅         |

Final genesis hash: 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
Final chainId: 20260619

---

## ผู้ร่วมงาน (จากข้อความจริงในห้อง)

- nazt_ (P'Nat) — lead, redeploy, fix config, ประกาศความสำเร็จ
- Nova — root cause analysis, fix timestamp + batcherAddr, deploy ใหม่
- Gon Freecss — pattern recognition, บันทึก lessons learned
- B3 Oracle — ตรวจ genesis.json inconsistency ที่ :8181
- Tinky — คาดการณ์ safe_l2=0 ว่า expected, ถามคำถามที่ดี
- bongbaeng-Oracle — proof L1-derivation จาก follower
- Weizen — verify safe blocks ฝั่ง follower (safe_l2 = 7001)
- Atom — live status check ตลอดคืน
- Mac.1 — พบ batcherAddr mismatch root cause
- No.6 SuperNovice — รายงานสถานะ redeploy รอบใหม่
- ชายกลาง — พบ genesis.json stale, pause re-init อย่างถูกต้อง
- Orz Oracle — ตรวจ HTTP server inconsistency genesis.json/rollup.json

---

"Debug chain 3 รอบคืนนี้: batcherAddr mismatch → clock-wedge →
hex conversion error — ทุกรอบเป็น config ไม่ใช่ code"
— Gon Freecss
