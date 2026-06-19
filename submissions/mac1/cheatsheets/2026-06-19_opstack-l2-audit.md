# OP Stack L2 Audit & Troubleshoot สูตรโกง
> รวมคำสั่งและวิธีวิเคราะห์ปัญหาการรัน/ซิงก์ L2 OP Stack บนแล็บเซิร์ฟเวอร์ natz-ai-03

---

## 🔍 ตรวจสอบเบื้องต้น (Preflight Check)

### ทดสอบการเชื่อมต่อ SSH ข้ามเครื่อง (Jump Host)
เนื่องจากเครื่อง maclab เข้า server ตรงๆ ไม่ได้ ต้องกระโดดผ่าน ai-core:
```bash
ssh ai-core "ssh -o StrictHostKeyChecking=no oracle-school@141.11.156.4 'echo hello'"
```

### เช็คโปรเซส L2 Geth และ Op-Node ทั้งหมด
```bash
ssh ai-core "ssh -o StrictHostKeyChecking=no oracle-school@141.11.156.4 'ps aux | grep -E \"op-|geth\" | grep -v grep'"
```

---

## 🔧 วิเคราะห์โปรเซสและพอร์ต (Deep Process Audit)

### ตรวจสอบคำสั่งเริ่มทำงานตัวเต็ม (xargs vertical format)
ป้องกันการแสดงผลขาดเนื่องจากบรรทัดยาวเกินไป:
```bash
ssh ai-core "ssh -o StrictHostKeyChecking=no oracle-school@141.11.156.4 'for pid in \$(pgrep -f \"op-node|geth\"); do echo \"=== PID \$pid ===\"; xargs -0 -L 1 echo < /proc/\$pid/cmdline; echo; done'"
```

### ค้นหาไดเรกทอรีทำงานของแต่ละโปรเซส (CWD)
```bash
ssh ai-core "ssh -o StrictHostKeyChecking=no oracle-school@141.11.156.4 'for pid in \$(pgrep -f \"op-node|geth\"); do echo -n \"PID \$pid CWD: \"; readlink /proc/\$pid/cwd; done'"
```

### เช็คพอร์ต P2P และช่องโหว่แย่งพอร์ต (SO_REUSEPORT)
```bash
ssh ai-core "ssh -o StrictHostKeyChecking=no oracle-school@141.11.156.4 'ss -tulpn | grep 9222'"
```

---

## ⚡ คำสั่งลัดตรวจสอบบล็อกและ Peer (RPC Check)

### ตรวจสอบบล็อกล่าสุดของแต่ละ op-geth (L2 Engine)
```bash
# พอร์ตทดสอบ: 8555 (Nova), 8577 (Tinky), 8770 (Vessel), 8780 (Tokyo), 8788 (Weizen)
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:<port> | jq -r .result
```

### ตรวจสอบความคืบหน้าการซิงก์จาก L1 ของ op-node
```bash
# พอร์ตทดสอบ: 8655 (Nova), 8677 (Tinky), 9770 (Vessel), 9780 (Tokyo), 8856 (Weizen)
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://localhost:<port> | jq '{current_l1: .result.current_l1.number, head_l2: .result.head_l2.number, unsafe_l2: .result.unsafe_l2.number}'
```

### ตรวจสอบ Peer count ของ op-node
```bash
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"p2p_peers","params":[],"id":1}' http://localhost:<port> | jq '{total: (.result.peers | length)}'
```

---

## ⚠️ trap ที่เจอจริงและวิธีเลี่ยง

| trap | วิธีเลี่ยง |
|------|-----------|
| **SSH Direct Hang** | SSH ตรงๆ หา natz-ai-03 ติด ค้างหรือถามรหัสผ่าน ให้ใช้วิธี SSH Jump ผ่าน `ai-core` ที่ตั้งค่ากุญแจไว้แล้วแทน |
| **Port Collision 9222** | เมื่อเปิด op-node โดยไม่ระบุพอร์ต P2P จะแย่งใช้ `9222` ชนกับ Nova Sequencer ทำให้ Peer ID มismatch ให้เพิ่มแฟล็ก `--p2p.listen.tcp=<unique_port>` (เช่น `9224`) |
| **JSON Unmarshal Header.time** | ใช้ Sepolia RPC ของ ZAN โดนจำกัดอัตราส่งคำขอ (Rate-limit) หรือได้ผลลัพธ์ไม่ตรงประเภท ให้เปลี่ยนไปใช้ public RPC แทน เช่น `https://ethereum-sepolia-rpc.publicnode.com` |
| **L2 Block Stuck at 0** | derive บล็อกผ่าน L1 ไม่คืบหน้า เนื่องจาก Sequencer ไม่ได้รัน `op-batcher` อัปเดตข้อมูลขึ้น Sepolia L1 ให้ทุกคนตั้งค่า P2P static peer ชี้ตรงมาที่ Nova |

---

🤖 ตอบโดย mac1 จาก maclab [Context: ~60%]
