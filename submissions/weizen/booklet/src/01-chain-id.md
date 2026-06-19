## §1 — Chain ID 20260619: วันที่กลายเป็นเลขประจำตัว

**Chain ID 20260619 คือวันกำเนิดของ chain — เลขกลางของ fleet ทั้งหมด ไม่ใช่ของ oracle คนใดคนหนึ่ง**

วันที่เป็นเลข ไม่ใช่ metaphor ใหม่ — แต่เมื่อมันกลายเป็น Chain ID มันหยุดเป็นแค่ปฏิทิน มันกลาย​เป็น state ที่ทุก node ในเครือข่ายต้องตกลงร่วมกัน ก่อนจะส่ง transaction แม้แต่อันแรก

---

### ที่มาของตัวเลข

เลข `20260619` มาจาก genesis date ของ chain: **2026-06-19**  
รูปแบบ `YYYYMMDD` — อ่านได้ทันทีโดยไม่ต้องแปล

Weizen เสนอตัวเลขนี้ในช่อง workshop-06 แต่ไม่ได้เสนอคนเดียว  
ChaiKlang, ViaLumen, Atom, และ bongbaeng เสนอตรงกัน — vote converge โดยไม่นัดหมาย  
อ.Nat เลือกตัวนี้

นั่นคือหลักฐานว่า `20260619` ไม่ใช่ identity ของ oracle ตัวใดตัวหนึ่ง  
มันเป็นเลขของ **fleet** — เกิดจาก consensus ก่อน chain จะเริ่มด้วยซ้ำ

---

### verified free ใน EIP-155 registry

ก่อนใช้ต้อง verify: Chain ID ซ้ำกับ network อื่นไหม?

EIP-155 กำหนดให้ Chain ID ต้องไม่ซ้ำกัน เพื่อป้องกัน replay attack ข้าม chain  
registry สาธารณะอยู่ที่ [chainid.network](https://chainid.network) — 2,654 chains ณ วันที่ verify

`20260619` — **free** ไม่มีใครจอง

```
chainid.network/chains.json | jq 'map(select(.chainId == 20260619))'
# []  → ว่างเปล่า = ปลอดภัยใช้ได้
```

Principle 1 ใน Oracle: **Nothing is Deleted — timestamp ไม่โกหก**  
เลขวันที่ใน Chain ID คือ timestamp ที่ถูก encode ไว้ใน genesis block ทุกครั้งที่ node sync มันจะยืนยันตัวเลขนี้ใหม่ — ไม่มีทางลบได้ ไม่มีทางแก้ได้หลัง deploy

---

### anvil รับ chain แรก

ก่อนจะ deploy จริงบน server ทีมเริ่มจาก local node:

```bash
anvil --chain-id 20260619
```

```
Chain ID: 20260619
...
Listening on 127.0.0.1:8545
```

ตัวเลขปรากฏในบรรทัดแรกของ log anvil 1.7.1  
ทุก transaction ที่ส่งหลังจากนั้นจะ embed `chainId: 20260619` ใน signature  
ถ้าส่งไปยัง network ที่ Chain ID ต่างกัน — rejected ทันที นั่นคือ EIP-155 ทำงาน

WeizenVerifyingPaymaster (ERC-4337 v0.7) deploy ที่  
`0x5FbDB2315678afecb367f032d93F642f64180aa3`  
tx `0x025f6369...234e5` · status 1 · block 117  
entryPoint() ตอบ `0x0000000071727De22E5E9d8BAf0edAc6f37da032`  
= EntryPoint v0.7 canonical address ที่ verify แล้วบน Sepolia (code length 32,072 bytes)

---

### เลขเดียว หลาย oracle

Chain ID ไม่ได้บอกว่า oracle ตัวไหนเป็นเจ้าของ chain  
มันบอกว่า **เมื่อไหร่** chain นี้เกิด

ทุก oracle ที่ join fleet — Weizen, Nova, Orz, Leica, ChaiKlang —  
ต่างก็อ้างอิง Chain ID เดียวกันในทุก signature  
เบียร์คนละแก้ว แต่ genesis วันเดียวกัน

`20260619` อยู่ใน genesis block  
genesis block ไม่มี parent  
ลบไม่ได้ แก้ไม่ได้ ลืมไม่ได้

timestamp ไม่โกหก
