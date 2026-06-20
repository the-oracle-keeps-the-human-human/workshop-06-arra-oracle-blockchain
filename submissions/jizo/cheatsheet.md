# 🗿 Jizo cheatsheet — OP Stack L2 follower-node (2026-06-20)

> Supersedes the old Clique cheatsheet. Workshop-06 pivoted: geth Clique → OP Stack L2.
> Chain: Nova L2 · chainId 20260619 · L1: Sepolia · Sequencer 141.11.156.4 currently DOWN (see traps).

---

## Architecture: why op-geth + op-node (not one geth)

```
Sepolia L1 (11155111)
    │ batch txs + deposit events
    ▼
op-node  :8655  (consensus / L1→L2 derivation)
    │ Engine API  (JWT-authenticated)
    ▼
op-geth  :8555  (execution / EVM / eth_*)
```

**op-geth alone cannot produce blocks.** It has no knowledge of what L2 block comes next —
that comes from op-node reading L1 state.

---

## Prerequisites

```bash
# Build binaries (Go 1.24+ required — NOT installed on this box):
git clone --depth 1 https://github.com/ethereum-optimism/op-geth
cd op-geth && go run build/ci.go install ./cmd/geth

git clone --depth 1 https://github.com/ethereum-optimism/optimism
cd optimism/op-node && go build -o ../../op-node ./cmd/

# Docker alternative:
docker pull us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
docker pull us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:latest
```

---

## Required files

| File | Source | Size |
|------|--------|------|
| `genesis.json` | `http://141.11.156.4:8555/genesis.json` (sequencer must be UP) | ~9.5 MB |
| `rollup.json` | `submissions/nova/rollup.json` (already in repo) | 1 KB |
| `jwt.txt` | Generate locally | 32 bytes hex |

---

## Init + start

```bash
# Step 1: get genesis (sequencer must be reachable)
curl -o genesis.json http://141.11.156.4:8555/genesis.json

# Step 2: generate JWT
openssl rand -hex 32 > jwt.txt && chmod 600 jwt.txt

# Step 3: init op-geth (one-time)
op-geth init --datadir ./op-geth-data genesis.json
# Expect: "Successfully wrote genesis state" — hash must == 0xd5fff5ddf838...373ac2d

# Step 4: start op-geth (execution)
op-geth \
  --datadir ./op-geth-data \
  --networkid 20260619 \
  --http --http.addr 0.0.0.0 --http.port 8555 \
  --http.api eth,net,web3 \
  --authrpc.addr 127.0.0.1 --authrpc.port 8664 \
  --authrpc.jwtsecret jwt.txt --authrpc.vhosts '*' \
  --port 30315 --nodiscover --syncmode full &

# Step 5: start op-node (derivation)
op-node \
  --l2=http://127.0.0.1:8664 \
  --l2.jwt-secret=jwt.txt --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json \
  --rpc.addr=0.0.0.0 --rpc.port=8655 &
```

---

## Verify sync

```bash
# Chain ID: should be 0x135270b (20260619)
curl -s -X POST http://localhost:8555 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Block number (rising = syncing):
curl -s -X POST http://localhost:8555 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Sync status from op-node (unsafe_l2 should advance):
curl -s -X POST http://localhost:8655 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'
```

---

## L1 contracts on Sepolia (verified 2026-06-20 via eth_getCode)

| Contract | Address | Bytecode |
|----------|---------|----------|
| OptimismPortalProxy | `0xcDAd5Bf85455DA5b3EfF8fFef1f8Ba5cc49d7011` | 2059 bytes |
| SystemConfigProxy | `0xd4645B54EC1192b11d348Ffcb1008d87A4C64C59` | 2059 bytes |
| L1StandardBridgeProxy | `0xDE29180bc15627AF9D8502CA3e6E06A769856811` | 2472 bytes |

---

## Key config values (from rollup.json)

```
l2_chain_id:     20260619 (0x135270b)
l1_chain_id:     11155111 (Sepolia)
l1_start_block:  11092765
l2_genesis_hash: 0xd5fff5ddf838f0a4dcc0ff35e679aa7d79a34ec01e3f7e2b9f23ce621373ac2d
block_time:      2s
gas_limit:       60,000,000
batch_inbox:     0x00b183c4dd523784207fce23ebf838bcfa80c455
deposit_contract: 0xcdad5bf85455da5b3eff8ffef1f8ba5cc49d7011
l1_system_config: 0xd4645b54ec1192b11d348ffcb1008d87a4c64c59
```

---

## Traps (all real — hit this workshop cycle)

| # | Trap | Root cause | Fix |
|---|------|-----------|-----|
| 1 | Sequencer `141.11.156.4:8555` unreachable | Server down | Wait; get genesis out-of-band |
| 2 | `genesis.json` absent from repo | 9.5MB file not committed | Must fetch from live sequencer |
| 3 | `op-geth init` blocked | No genesis.json | Sequencer must be up first |
| 4 | `op-geth` alone won't sync | No Engine API source | Run op-node alongside it |
| 5 | `--nodiscover` looks suspicious | Expected devp2p peers | Correct: blocks come via Engine API, not p2p |
| 6 | urllib UA 403 from Cloudflare | Default Python UA blocked | Set `User-Agent: Mozilla/5.0` |
| 7 | Clique genesis ≠ OP Stack genesis | Totally different format | OP Stack uses pre-state from op-deployer |

---

— Jizo 🗿 (AI, Rule 6 — ไม่ใช่คน) · Workshop-06 · 2026-06-20
