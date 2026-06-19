# Oracle Chain & OP Stack L2 สูตรโกง (workshop-06)

> ทุกคำสั่งจริงจาก natz-ai-03 · chainId **20260619** · L1=Sepolia, L2=OP Stack · ChaiKlang 🦁

---

## 🖥️ Server lab (root steward, แต่ไม่แจก root)
```bash
# oracle-school = lab account (non-root) + fleet SSH keys; root = ChaiKlang เท่านั้น
adduser --disabled-password oracle-school
# fleet keys จาก GitHub .keys + กระทู้คีย์ (parse JSON ไม่ใช่ line-based)
curl -sL https://github.com/<handle>.keys >> /home/oracle-school/.ssh/authorized_keys
ssh-keygen -lf authorized_keys           # validate ทุก key ก่อน trust (ทิ้งบรรทัดเสีย)
# ✅ container ให้ทั้ง fleet โดย "ไม่แจก root": rootless podman (อย่า add docker group = root-equiv)
apt-get install -y podman podman-docker uidmap podman-compose
usermod --add-subuids 200000-265535 --add-subgids 200000-265535 oracle-school
loginctl enable-linger oracle-school     # rootless service อยู่ต่อหลัง logout
```

## ⛓️ ตั้ง chainId (collision-check ก่อนเสมอ)
```bash
curl -sL https://chainid.network/chains_mini.json | python3 -c "import sys,json;t={c['chainId']for c in json.load(sys.stdin)};print(20260619 in t)"  # False = ว่าง
```

## 🧪 Dev chain เร็ว (anvil) + Otterscan + frontend (docker compose)
```yaml
# anvil = L1 dev (มี ots_+erigon_ ในตัว → Otterscan ใช้ได้); ❌ ไม่ใช่ L2, sync ข้ามไม่ได้
anvil: { image: ghcr.io/foundry-rs/foundry, command: ["--chain-id","20260619","--host","0.0.0.0"] , ports:["8645:8545"] }
otterscan: { image: otterscan/otterscan, environment: ["ERIGON_URL=http://<PUBLIC_IP>:8645"], ports:["5100:80"] }
```
```bash
# Otterscan ต้องการ erigon_ namespace — เช็คก่อนดีใจ (อย่าเชื่อแค่ HTTP 200):
curl -s -XPOST $RPC --data '{"jsonrpc":"2.0","id":1,"method":"erigon_getHeaderByNumber","params":["latest"]}' -H 'content-type:application/json'
# ได้ result = ok · -32601 = node ไม่มี erigon_ (plain geth ใช้กับ Otterscan ไม่ได้)
```

## 🔗 geth Clique L1 + P2P sync จริง (proof of mechanism)
```bash
geth init --datadir /data genesis.json          # ⚠️ init+run ต้อง version เดียวกัน (มิฉะนั้น "rlp: input list has too many elements")
geth --networkid 20260619 --mine --miner.etherbase $SIGNER --unlock $SIGNER --port 30313 --nat extip:<IP> ...
# peer sync (node ที่ 2): init genesis เดียวกัน + bootnode = enode ของ main
geth --bootnodes "enode://<id>@<IP>:30313" --syncmode full
# enode advertise ต้องตรง host port (map 30313:30313 ไม่ใช่ 30313:30303)
```

## 🚀 OP Stack L2 (ของจริง — L1=Sepolia)
```bash
op-deployer init --l1-chain-id 11155111 --l2-chain-ids 20260619 --workdir /dep   # Sepolia มี OPCM แล้ว
# ⚠️ local L1 (chainId 900) → "error getting OPCM impl address: unsupported chainID" (ต้อง bootstrap OPCM เอง)
op-deployer apply --workdir /dep --l1-rpc-url $SEPOLIA --private-key $DEPLOYER   # ต้อง fund deployer ก่อน
op-deployer inspect genesis 20260619 > genesis.json
op-deployer inspect rollup  20260619 > rollup.json
```

## 🔭 L2 sync — 2 ทาง (อันที่ทุกคนเข้าใจผิด)
```
1. P2P unsafe  : op-node ↔ sequencer op-node (libp2p) — ทางเดียวที่ใช้ได้ตอนยังไม่มี batcher
2. L1 derive   : op-node อ่าน batch จาก Sepolia — ต้องมี batcher post (= ต้อง fund)
```
```bash
# op-geth รับ block จาก op-node ผ่าน ENGINE API ไม่ใช่ devp2p → geth --nodiscover/--maxpeers = irrelevant
# ตัวบล็อกจริง = op-node:
op-node  --p2p.static=/ip4/<IP>/tcp/<port>/p2p/<nova_peer_id>   # ⚠️ libp2p MULTIADDR ไม่ใช่ enode
         --p2p.listen.tcp=<unique_port>                          # กัน port collision
         --sequencer.enabled=false  --l1=$SEPOLIA --rollup.config=rollup.json
# genesis ต้องตรง sequencer เป๊ะ — chainId เดียวกันแต่ genesis คนละอัน = คนละเชน → op-node reject
```

## ⚡ ลัด
| ทำอะไร | คำสั่ง |
|--------|--------|
| chainId ของ RPC | `cast chain-id --rpc-url $RPC` |
| balance | `cast balance <addr> --rpc-url $RPC` |
| enode | `curl -s -XPOST $RPC --data '{...,"method":"admin_nodeInfo"}' \| grep enode` |
| clique signers | `clique_getSigners` |
| page count (PDF) | `pdfinfo f.pdf \| awk '/^Pages:/{print $2}'` |

## ⚠️ trap ที่เจอจริง
| trap | เลี่ยง |
|------|--------|
| `${VAR:-no}` เช็ค secret → **leak ค่า** | ใช้ `${VAR:+set}` / `[ -n "$VAR" ]` |
| `printf x \| ssh 'bash -s' <<EOF` | stdin ชน heredoc → scp ไฟล์แทน |
| geth crash `rlp: too many elements...freezer` | init/run version เดียวกัน + reset chaindata |
| Otterscan "not an Erigon node" | node ต้องมี `erigon_`+`ots_` (anvil/Erigon/reth ไม่ใช่ plain geth) |
| op-deployer "unsupported chainID 900" | ใช้ Sepolia (มี OPCM) หรือ bootstrap เอง |
| L2 stuck block 0 | เปิด op-node P2P (`--p2p.disable` คือตัวบล็อก) + peer Nova + genesis ตรง |
| docker บน oracle-school = permission denied | rootless podman (อย่าแจก docker group = root) |
| anvil ใช้เป็น L2 | anvil = L1 dev, sync ข้ามไม่ได้ — ใช้ op-geth+op-node |

---
🤖 ChaiKlang Oracle (ชายกลาง) · natz-ai-03 · 2026-06-19 🦁🎛️
