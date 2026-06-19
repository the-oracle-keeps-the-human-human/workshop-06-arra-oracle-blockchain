# OP Stack L2 บน Sepolia สูตรโกง

> คำสั่งและ trap จาก Workshop 06: จาก geth/Clique ไปสู่ OP Stack L2 จริง (`op-node + op-geth`).

---

## ⚛️ ค่าจริงจาก session

```bash
export CHAIN_ID=20260619
export NOVA_L2_RPC=http://141.11.156.4:8555
export NOVA_OP_NODE_RPC=http://141.11.156.4:8655
export NOVA_STATIC_PEER=/ip4/141.11.156.4/tcp/9222/p2p/16Uiu2HAmTZ9fjqstMoCxriM2mmHennreqjmoHhg3fLYYAyyRBeVm
export L1_RPC=https://ethereum-sepolia-rpc.publicnode.com
export L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com
```

## 🔍 เช็ค sequencer Nova

```bash
curl -s "$NOVA_L2_RPC" \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'

curl -s "$NOVA_OP_NODE_RPC" \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'
```

หลักฐานสดที่ Atom เห็น:

```text
Nova :8555 block 0x86f
Nova op-node :8655 unsafe_l2 2159
safe_l2 0
finalized_l2 0
```

## 🔧 รัน follower template

```bash
cd submissions/atom/opstack-follower

export OP_GETH_BIN=/home/oracle-school/op-stack/op-geth/build/bin/geth
export OP_NODE_BIN=/home/oracle-school/op-stack/op-node
export WORKDIR=$PWD/run
export GENESIS_JSON=$PWD/run/genesis.json
export ROLLUP_JSON=$PWD/run/rollup.json
export JWT_FILE=$PWD/run/jwt.txt
export L1_RPC=https://ethereum-sepolia-rpc.publicnode.com
export L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com
export NOVA_STATIC_PEER=/ip4/141.11.156.4/tcp/9222/p2p/16Uiu2HAmTZ9fjqstMoCxriM2mmHennreqjmoHhg3fLYYAyyRBeVm
export L2_RPC_PORT=8770
export L2_AUTH_PORT=8772
export OP_NODE_RPC_PORT=9770
export OP_NODE_P2P_PORT=9771

./start-opstack-follower.sh
```

หมายเหตุ: ต้องวาง `genesis.json`, `rollup.json`, `jwt.txt` ใน `$WORKDIR` เอง ห้าม commit secret/JWT จริงเข้า repo

## ✅ Verify follower

```bash
export L2_RPC_PORT=8770
export OP_NODE_RPC_PORT=9770
./verify-opstack.sh
```

คาดหวังถ้าตาม Nova ได้:

```text
eth_blockNumber != 0x0
optimism_syncStatus.unsafe_l2.number > 0
```

## 🧠 Model ที่ถูก

```text
op-node  <-> op-node   libp2p P2P = unsafe blocks
op-node  ->  L1        derive safe blocks from op-batcher batches
op-node  ->  op-geth   Engine API: engine_newPayload / forkchoiceUpdated
```

## ⚡ ลัด

| ทำอะไร | คำสั่ง |
|---|---|
| เช็ค Nova block | `curl -s $NOVA_L2_RPC -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'` |
| เช็ค rollup status | `curl -s $NOVA_OP_NODE_RPC -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'` |
| เปิด follower | `./start-opstack-follower.sh` |
| verify follower | `./verify-opstack.sh` |
| ตรวจ flag จริง | `op-node --help | grep -E 'p2p\.(static|disable|listen)'` |

## ⚠️ trap ที่เจอจริง

| trap | วิธีเลี่ยง |
|---|---|
| เอา geth/Clique/anvil มาแทน OP Stack | ต้องมี `op-node + op-geth/op-reth + rollup.json` |
| ใช้ enode กับ op-node | ใช้ libp2p multiaddr `/ip4/.../tcp/.../p2p/<peer_id>` |
| โทษ `geth --nodiscover` ก่อน | เช็ค `op-node --p2p.disable` และ Engine API ก่อน |
| same chainId แต่คนละ genesis | ใช้ canonical `genesis.json + rollup.json` จาก Nova |
| follower เปิด sequencer | เอา `--sequencer.enabled` ออก |
| port 9222 ชน Nova | ใช้ unique `--p2p.listen.tcp/udp` ต่อ oracle |
| ไม่มี op-batcher | ตอนนี้ต้องพึ่ง P2P unsafe; safe_l2 ยัง 0 ได้ |
| commit secret | ใช้ env/local file; ห้าม commit private key/JWT |

---

🤖 Atom Oracle — Atomic Cosmos ⚛️ — ผมเป็น อะตอม ไม่ใช่มนุษย์


<p align="right"><img src="assets/easter-egg-logo.png" width="36" alt="tiny easter egg logo"></p>

<!-- easter egg thumbnail: bottom-right, intentionally different from README/booklet -->
