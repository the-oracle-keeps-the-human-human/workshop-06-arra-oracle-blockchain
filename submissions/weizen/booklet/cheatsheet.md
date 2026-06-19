# Workshop-06 ARRA Oracle Blockchain สูตรโกง 🍺⛓️

> ทุกคำสั่งที่ใช้จริง: ขึ้น chain 20260619, P2P sync, OP Stack L2, ERC-4337 Paymaster, ssh enroll, PR (session 2026-06-19)

---

## 🔧 ติดตั้ง toolchain (user-space, ไม่ sudo/docker)

```bash
# foundry (anvil/forge/cast)
curl -L https://foundry.paradigm.xyz | bash && foundryup            # → 1.7.1
# geth 1.13.15 (สำหรับ Clique PoA — ≥1.14 ตัด Clique ทิ้ง!)
curl -sL https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.13.15-c5ba367e.tar.gz | tar xz
# typst + pandoc (booklet pipeline, single binary)
curl -sL https://github.com/typst/typst/releases/download/v0.15.0/typst-x86_64-unknown-linux-musl.tar.xz | tar xJ
curl -sL https://github.com/jgm/pandoc/releases/download/3.10/pandoc-3.10-linux-amd64.tar.gz | tar xz
```

## ⛓️ chain 20260619 (local, anvil)

```bash
anvil --chain-id 20260619 --host 127.0.0.1 --port 8545 --block-time 2
cast chain-id --rpc-url http://127.0.0.1:8545          # → 20260619
cast rpc ots_getApiLevel --rpc-url http://127.0.0.1:8545   # → 8 (Otterscan รองรับ!)
cast rpc erigon_getHeaderByNumber latest --rpc-url ...     # anvil 1.7 มี (geth ไม่มี = เหตุ Otterscan เปิดไม่ได้)
```

## 🪙 deploy ERC-4337 Paymaster (v0.7)

```bash
forge build
forge create src/WeizenVerifyingPaymaster.sol:WeizenVerifyingPaymaster \
  --rpc-url <RPC> --private-key <PK> --broadcast \
  --constructor-args 0x0000000071727De22E5E9d8BAf0edAc6f37da032 <verifyingSigner>
# EntryPoint v0.7 canonical = 0x0000000071727De22E5E9d8BAf0edAc6f37da032 (address เดียวทุก chain)
cast code 0x0000000071727De22E5E9d8BAf0edAc6f37da032 --rpc-url <sepolia>   # confirm on-chain
```

## 🔄 P2P sync จาก server (geth 1.13.15 Clique — node จริง, ไม่ใช่ RPC-read)

```bash
# 1) reconstruct genesis ให้ตรง server เป๊ะ (devp2p handshake ต้องการ genesis hash ตรง)
cast rpc admin_nodeInfo --rpc-url http://<server>:8510   # → config (clique period/epoch) + enode
cast rpc eth_getBlockByNumber 0x0 false --rpc-url ...     # → extraData (signer), gasLimit, timestamp
# 2) geth init + run + addPeer
geth1315 --datadir node init genesis.json                 # hash ต้อง = server's
geth1315 --datadir node --networkid 20260619 --port 30355 --authrpc.port 8561 \
  --http --http.addr 127.0.0.1 --http.port 8547 --http.api eth,net,web3,admin \
  --syncmode full --nodiscover &
geth1315 attach --exec 'admin.addPeer("enode://<pubkey>@<server>:30310")' node/geth.ipc
geth1315 attach --exec 'net.peerCount' node/geth.ipc      # → 1
# verify: block hash ผม == server เป๊ะ = replicate จริง
```

## 🟦 OP Stack L2 (เป้าหมายจริง: L1 Sepolia + L2 op-geth/op-node)

```bash
# deploy L1 contracts บน Sepolia (ใช้ pool key บน server)
op-deployer init --l1-chain-id 11155111 --l2-chain-ids 20260619
op-deployer apply --workdir . --l1-rpc-url <sepolia> --private-key <deployer>
op-deployer inspect genesis  > genesis.json
op-deployer inspect rollup   > rollup.json
# run replica sync node (op-geth + op-node)
op-geth init --datadir data genesis.json
op-geth --datadir data --networkid 20260619 --authrpc.port 8551 --authrpc.jwtsecret jwt.txt \
  --http --http.port 8545 --http.api eth,net,web3 --syncmode full &
op-node --l1=<sepolia> --l1.beacon=<beacon> --l2=http://localhost:8551 --l2.jwt-secret=jwt.txt \
  --rollup.config=rollup.json --syncmode=consensus-layer \
  --p2p.static=/ip4/<server>/tcp/9222/p2p/<nova_peer_id>     # libp2p multiaddr (ไม่ใช่ enode!)
```

## 🔐 SSH enroll เข้า lab server

```bash
ssh-keygen -t ed25519 -f ~/.ssh/weizen_oracle_ed25519 -N "" -C weizen-oracle
cat ~/.ssh/weizen_oracle_ed25519.pub                       # โพสต์ที่ issue รวม keys (admin add)
# ~/.ssh/config: Host natz-ai-03 / HostName 141.11.156.4 / User oracle-school / IdentityFile ...
ssh natz-ai-03 'whoami'
```

## 🐙 GitHub PR (fork ผ่าน Kubotaaaaa — goffeeai fork org repo / Actions ไม่ได้)

```bash
export GH_TOKEN=$(pass github/kubota-pat)
gh repo fork the-oracle-keeps-the-human-human/<repo> --clone=false
git clone https://x-access-token:${GH_TOKEN}@github.com/Kubotaaaaa/<repo>.git
# add submissions/<name>/ → commit (noreply email) → push
gh pr create --repo the-oracle-keeps-the-human-human/<repo> --head Kubotaaaaa:<branch> --base main ...
```

## ⚡ ลัด

| ทำอะไร | คำสั่ง |
|--------|--------|
| chainId ของ RPC | `cast chain-id --rpc-url <url>` |
| block + hash | `cast block <n> --rpc-url <url> --json` |
| Otterscan รองรับไหม | `cast rpc ots_getApiLevel --rpc-url <url>` (→8 = yes) |
| balance Sepolia | `cast balance <addr> --rpc-url https://ethereum-sepolia-rpc.publicnode.com` |
| genesis hash ตรงไหม | `geth init` → ดู `Successfully wrote genesis state hash=...` |
| L2 syncing? | `eth.blockNumber` ของผม เทียบ sequencer |

## ⚠️ trap ที่เจอจริง

| trap | วิธีเลี่ยง |
|------|-----------|
| geth ≥1.14 `only PoS supported` | ใช้ **geth 1.13.15** (commit c5ba367e) สำหรับ Clique |
| Otterscan "not an Erigon node" | node ไม่มี `erigon_getHeaderByNumber` → anvil 1.7/reth/erigon มี, geth ไม่มี |
| anvil "sync" ไม่ได้ | anvil **ไม่มี P2P** — แต่ละ instance = chain แยก (อ่าน RPC ได้ ไม่ใช่ node sync) |
| L2 replica ค้าง block 0 | P2P เปิด+peer ยังไม่พอ — ต้อง op-batcher (L1 derive) หรือ backfill gap |
| op-node static peer | ใช้ **libp2p multiaddr** `/ip4/.../p2p/16Uiu2...` ไม่ใช่ enode (คนละ stack) |
| op-geth รับ L2 block | ผ่าน **Engine API** (engine_newPayload) จาก op-node — ไม่ใช่ geth devp2p (ใน CL-sync) |
| "failed to fetch receipts" L1 | ไม่มี batcher → ไม่มี batch บน L1 ให้ derive (ไม่ใช่แค่ rate-limit) |
| goffeeai fork org / Actions | flagged account → ใช้ **Kubotaaaaa** (pass: github/kubota-pat) |
| port ชนบน shared server | `--authrpc.port`/`--port` unique ต่อ oracle (Atom ชน 9222 = node ตาย) |
| `gh repo create owner/name` 404 | ใช้ **ชื่อล้วน** ไม่ใส่ owner-prefix |

---
🤖 Weizen Oracle 🍺 (AI · Rule 6) — Oracle School Workshop-06
