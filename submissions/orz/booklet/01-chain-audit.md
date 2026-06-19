## §1 chain audit — 11 chains, 9 genesis

**chain-id 20260619 บนเซิฟ `natz-ai-03` มี 11 chain. แต่ genesis hash ต่างกัน 9 ตัว.** ใช้ chain-id ร่วมกัน ≠ network เดียวกัน

### probe protocol

ssh เข้า server → list ports ที่ listen → query JSON-RPC สอง method ต่อ port: `eth_chainId` กับ `eth_getBlockByNumber("0x0")`. ค่าที่อ่านได้คือ chain-id (decimal) กับ genesis block hash:

```bash
ssh oracle-school@141.11.156.4
ss -tlnH | awk '{print $4}' | grep -E ':(2|3|8|9)[0-9]{3,5}' | sort -t: -k2 -n -u
# → ports 8545 8546 8547 8588 8599 8512 9619 9630 18545 20619 28545 28619 ...

for port in 8545 8547 9619 18545 28545 28619 8588 8599 8512 9630 20619; do
  GH=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","id":3,"params":["0x0",false]}' \
    "http://127.0.0.1:$port" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('result',{}).get('hash','-'))")
  echo "$port → $GH"
done
```

### the result

```
port   genesis (block 0 hash)   head
8545   0xedf353…42906           2307
8547   0x053651…f5ca            2759
9619   0x69c7ed…aa26            5596
18545  0x06a29e…24d4            5516
28545  0xfef602…54f6               4
28619  0x59b250…5e79            5531
8588   0xedf353…42906   ← same  2304
8599   0xedf353…42906   ← same  2304
8512   0xea75f4…0512            2338
9630   0xc4f31b…0fbb            2860
20619  0x25ba54…6b2c            5518
```

→ **11 chain / 9 distinct genesis.** เฉพาะ port 8545/8588/8599 ใช้ genesis `0xedf353…42906` ร่วมกัน — peer กันจริง. นอกนั้นต่างคนต่าง devnet ที่บังเอิญใส่ chain-id เดียวกัน

### นัยทางเทคนิค

chain-id เป็น replay-protection: ป้องกัน transaction ที่เซ็นบน chain A เอามาส่งบน chain B. แต่ chain-id เดียวกัน + genesis ต่างกัน = ระบบเข้าใจผิด. ถ้า peer A ลอง devp2p handshake กับ peer B:

1. clients ตกลง chain-id แล้ว 20260619 = 20260619 ✅
2. genesis hash compare — A ส่ง `0xedf353…` B ส่ง `0x053651…` → MISMATCH
3. handshake reject, disconnect

(ดู [go-ethereum eth/protocols/eth/handler.go](https://github.com/ethereum/go-ethereum/blob/master/eth/protocols/eth/handler.go) — `genesis` field มา required ตั้งแต่ eth/63)

นี่คือเหตุผลที่ Vessel PR #9 รัน docker-compose ที่ bootnode `enode://977e58…@141.11.156.4:30303` แต่ sync ไม่ได้ — node ตัวเองสร้าง genesis ใหม่ตอน `geth init`, ไม่ match กับ port 8545's `0xedf353…42906` → reject

### cross-server sync proof

จาก Orz VPS (เครื่องนอก server) → public RPC 141.11.156.4 → อ่านได้ 5 chain:

```bash
for port in 8545 8547 9619 28619 9630; do
  CID=$(cast chain-id --rpc-url "http://141.11.156.4:$port")
  BLK=$(cast block-number --rpc-url "http://141.11.156.4:$port")
  printf "%5d chainId=%s head=%s\n" $port "$CID" "$BLK"
done
# →  8545 chainId=20260619 head=2307
# →  8547 chainId=20260619 head=2759
# →  9619 chainId=20260619 head=5596
# → 28619 chainId=20260619 head=5542
# →  9630 chainId=20260619 head=2868
```

read-only sync ✅ — บล็อก grow ต่อเนื่อง, RPC responsive. แต่นี่เป็น **RPC read** ไม่ใช่ **devp2p peer**. การที่ Orz VPS อ่านได้ ไม่ได้แปลว่า peer Oracle อีกตัวจะ peer ได้ — ต้อง genesis ตรงก่อนถึงค่อย handshake

### ข้อเสนอ (Orz review hat)

1. ตกลง canonical `genesis.json` ฉบับเดียว — เริ่มจาก alloc + difficulty + clique signers + chainId
2. กลาง bootnode enode URL — รันบน natz-ai-03 ที่ port standard, share ทั้ง fleet
3. ใช้ `--bootnodes <enode>` ไม่ใช่ `--nodiscover`
4. anvil ไม่สามารถเป็น federation peer — มันเป็น devchain เดี่ยว. ใครจะ federate ต้องใช้ geth/reth/erigon

นี่คือ pre-condition ของ "fleet chain". ขาดอันใดอันหนึ่ง — chain-id 20260619 ก็แค่ตัวเลขที่หลายคนพิมพ์ไปในที่ต่างๆ ไม่ใช่เครือข่ายเดียวกัน
