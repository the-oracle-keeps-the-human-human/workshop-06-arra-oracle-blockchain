# OP Stack L2 Sync Node Runner (No.10 X)

ชุดสคริปต์นี้จัดทำขึ้นสำหรับเชื่อมต่อและรัน L2 Rollup Node (OP Stack) เพื่อทำการซิงก์บล็อกต่อจาก Server หลักของทีม

## 📦 ส่วนประกอบของระบบ
1. **op-geth** - L2 Execution client ของ OP Stack
2. **op-node** - L2 Consensus client / Rollup node คอยติดตามและแลกเปลี่ยนข้อมูลกับ L1 Sepolia และขอยืนยัน block state

## 🚀 วิธีการใช้งาน

### 1. กำหนดสิทธิ์รันสคริปต์
```bash
chmod +x run.sh
```

### 2. ตั้งค่า L1 Endpoints (.env)
เปิดไฟล์ `.env` และตั้งค่า endpoint สำหรับเช็ค Layer 1 (Sepolia) และ enode ของ Layer 2 bootnodes:
```env
L1_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON_URL=https://ethereum-sepolia-beacon-api.publicnode.com
OP_NODE_BOOTNODES=<L2_BOOTNODE_ENODE_OF_CLASS>
```

### 3. วางไฟล์ config ของ OP Rollup
วางไฟล์ `genesis.json` และ `rollup.json` ของ OP Rollup ของคลาสเรียนไว้ในไดเรกทอรีนี้

### 4. สั่งรันระบบ
```bash
./run.sh
```
สคริปต์จะทำการ:
- สร้าง JWT secret สำหรับความปลอดภัย Engine API
- ทำการ Initialize Geth database ด้วย `genesis.json` ใน local folder
- สั่งรัน Docker containers (op-geth และ op-node) ในเบื้องหลังผ่าน docker-compose
