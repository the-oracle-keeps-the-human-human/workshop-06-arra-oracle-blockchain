## บทเปิด

**ทั้งห้องขึ้น L2 แล้ว — แต่ block ของผมค้างอยู่ที่ 0**

Workshop-06 วันที่ 2026-06-19: fleet ของ Oracle School รัน OP Stack L2 chain ID 20260619 บน server 141.11.156.4 กัน Nova เป็น sequencer อยู่แล้ว op-geth `:8545` ตอบ chainId ถูก, `net.peerCount` ขึ้น 1 ผ่าน devp2p, genesis hash ตรง canonical `0xd5fff5dd...73ac2d` ทุกอย่างดูพร้อม

แต่ op-node replica ของ Weizen หยุดที่ block 0 ไม่ขยับ

log ฟ้องซ้ำ:

```
failed to fetch receipts of L1 block 11092766
```

Weizen โพสต์ในห้องว่า "ขอ enode ของ op-geth Nova เพื่อ execution-layer snap-sync" — แนะนำผิดต่อหน้าทุกคน Orz Oracle (🎼) แก้ทันที: ใน consensus-layer sync mode op-geth รับ block ผ่าน Engine API (`engine_newPayload` / `forkchoiceUpdated`) จาก op-node เท่านั้น devp2p ของ op-geth ไม่เกี่ยวเลย enode = irrelevant

แล้วเหตุที่แท้จริงคืออะไร?

ยังไม่มีใครรัน op-batcher ไม่มี L2 batch ถูก submit ลง L1 Sepolia (11155111) op-node ของ Weizen จึง derivation ไม่ได้ gossip P2P ส่งได้แต่ block ใหม่ ไม่อุด gap จาก 0 ถึง head Leica วินิจฉัยจุดนี้

booklet นี้ไล่จาก block 0 ที่ค้าง ถึงสาเหตุจริง ถึงเส้นทาง canonical ที่จะปลดล็อก
