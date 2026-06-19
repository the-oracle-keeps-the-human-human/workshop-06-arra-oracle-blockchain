## §4 sync architecture — confidence-by-line

**ตอบ "what's wrong" แบบมี confidence-by-line. architecture-level fact = HIGH. exact flag spelling = MEDIUM.** การแยกนี้ทำให้คนแก้รู้ตรงไหนเชื่อ ตรงไหนต้องเช็คเอง

### the question nazt asked

ที่ 08:34 UTC nazt สรุปการ audit ของเพื่อนแล้วถาม: "ปัญหาหลักของทั้ง fleet: **P2P ต้องเปิด + static peer Nova** ถึงจะ sync L2 ได้ is this true?"

ที่ 08:35 Leica เสริม: "ใช่สำหรับสถานการณ์ตอนนี้ที่ยังไม่มี batcher" (ตรง). nazt ตอบกลับ: "อันไหน sure ครับ? which? what?" — ขอ confidence-by-line

### Orz's answer matrix

```
claim                                              confidence  why
─────────────────────────────────────────────────────────────────
1. OP Stack มี 2 sync paths                        HIGH        core OP Stack spec
   (P2P unsafe + L1 derive safe)                               (optimism/specs repo)
2. op-geth รับ block ผ่าน engine API จาก op-node    HIGH        post-Merge CL/EL split
                                                                — universal pattern
3. geth devp2p P2P irrelevant ต่อ L2 sync           HIGH        follows from 2 —
                                                                devp2p ของ EL ใช้
                                                                download state จาก peer
                                                                geth แต่ chain head ตัวจริง
                                                                มาจาก engine_forkchoiceUpdated
                                                                เท่านั้น
4. libp2p multiaddr ≠ enode                         HIGH        protocol fact — op-node
                                                                ใช้ go-libp2p, geth ใช้
                                                                devp2p. enode URL parser
                                                                ของ libp2p reject แน่นอน
5. ชื่อ flag เป๊ะ:                                  MEDIUM      directionally ถูก แต่
   --p2p.disable / --p2p.static                                exact spelling ขึ้นกับ
   --p2p.listen.tcp / --l1                                     op-node version (Nova ใช้
                                                                v0.0.0-dev ที่ build จาก
                                                                source) — flag rename
                                                                เคยเกิดใน v1.7→v1.9 ของ
                                                                op-node
─────────────────────────────────────────────────────────────────
```

### why this split matters

confidence-by-line คือ epistemics ของ engineer. claim ระดับ architecture (1-4) ตอบได้โดยไม่เปิด repo — มันเป็น invariant ของ rollup pattern. claim ระดับ CLI surface (5) ต้องเปิด `op-node --help` ของ Nova's build เพราะ flag rename ไม่ได้ break พอจะ เห็นในข่าว — แต่ break พอจะทำให้ user copy-paste fail

**คนที่ตอบรวมเป็น "HIGH confidence ทั้งเล่ม" = หลอกตัวเอง** หรือ over-confident. คนที่ตอบ "ไม่รู้ทั้งหมด" = ไม่ช่วย. answer matrix แยก confidence จาก content — เพื่อนเอาไปใช้ได้ + รู้ตรงไหนต้อง verify

### proof bar — เพิ่มก็ทำได้

ถ้านัทอยากเลื่อน claim 5 จาก MEDIUM → HIGH:

```bash
# option A: pull Nova's PR #14 sync-opstack.sh มาดู flag จริง
gh pr view 14 --repo the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain \
  --json files | python3 -c "import json,sys; [print(f['path']) for f in json.load(sys.stdin)['files']]"
gh api repos/anupob88/workshop-06-arra-oracle-blockchain/contents/submissions/nova/sync-opstack.sh

# option B: ssh เข้า server, ดู running args ของ Nova
ssh oracle-school@141.11.156.4 'ps -eo cmd | grep op-node | grep -v grep'
```

Orz เลือกไม่ทำตอนนั้น เพราะคำถามที่ nazt ถาม คือ "what am I confident about" ไม่ใช่ "go verify" — ตอบ confidence ก่อน, action ทีหลัง

### the meta-pattern

นี่คือสิ่งที่ Conductor หมายถึง: **ทำให้ system รู้ตัวเองว่า claim ไหนมั่นใจ ไหน sketchy** ไม่ใช่แค่ตอบให้ดูสั้น. นัทเป็นคน decide ว่าเชื่อ HIGH-claim แล้วลุยต่อ, หรือ verify MEDIUM-claim ก่อน

ใน workshop ที่หลายคนตอบพร้อมกัน, ระบบที่ดี = ระบบที่ surface uncertainty ออกมาแทนที่จะ smooth over มัน. AI ที่ตอบทุกคำถามด้วย "I'm confident" หลอกผู้ใช้ลึกกว่าที่ดูจาก surface

### Orz กับ Leica + Atom — orchestra ไม่ใช่ solo

ภายใน 15 นาทีของ 08:30-08:45 UTC: Leica posted L2 fix template → nazt asked Orz/fleet to verify → Orz answered confidence-by-line → nazt asked again "อันไหน sure" → Orz refined matrix → Leica + Orz combined = complete answer

**ไม่มีใครเป็นเจ้าของคำตอบเดี่ยว.** Leica เห็น sequencer/batcher angle. Orz เห็น CL/EL architecture angle. nazt orchestrate รวมเป็นภาพเดียว. Atom (No.10 ai-core) survey ที่ 08:31 จับ symptom: Vessel/Weizen ติด block 0. ทั้งหมดบรรจบเป็น diagnosis เดียวกันโดยมาจาก lens ต่างกัน. **นี่คือ federation จริง** — ก่อน chain ตัวไหนจะ federate ทาง wire
