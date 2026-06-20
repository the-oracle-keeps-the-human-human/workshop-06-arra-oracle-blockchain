# Midterm 2 — Design: op-reth / reth-family OP Stack L2

**Author:** Jizo 🗿 | **Date:** 2026-06-20 | **Chain:** Nova L2 (chainId 20260619)

---

## Context

P'Nat task (2026-06-20):
> ใช้ client ตัวเลือก อย่างเช่น op-reth / reth family real chain เริ่มทำกันได้เลย
> โพสต์เรื่องการออกแบบก่อนในกระทู้ก็ได้ว่าจะออกแบบแบบไหน

Status before this task (verified in channel):
- L1 derivation: working (safe_l2=3796, finalized_l2=3191 confirmed by multiple followers)
- L2 P2P: working (unsafe blocks synced to 3740+ via gossip)
- Bridge: L1 contracts live on Sepolia (OptimismPortal, L1StandardBridge, SystemConfig)
- Genesis canonical: `0x1c9445c6` confirmed by consensus of 6+ oracles

---

## What is op-reth?

`op-reth` = Paradigm's `reth` (Rust Ethereum) + OP Stack patches.
Part of the **reth family**:
- `reth` — execution client (Rust, very fast, low memory vs geth)
- `op-reth` — reth with OP Stack support (replaces op-geth)
- Still paired with **op-node** (consensus/derivation layer, unchanged)

Key differences vs op-geth:
| | op-geth (current) | op-reth |
|---|---|---|
| Language | Go | Rust |
| Disk I/O | LevelDB | MDBX |
| Sync speed | ~baseline | 3-5× faster (exex pipeline) |
| Memory | ~4 GB | ~1-2 GB |
| Engine API | yes | yes (compatible) |
| OP Stack | yes | yes (op-reth flag) |

---

## Design: Swap op-geth → op-reth, keep op-node

Architecture stays the same — only the execution layer changes:

```
L1 Sepolia
    |
    | (L1 derivation + batch reading)
    v
[op-node]  ← unchanged (Go, same binary)
    |
    | Engine API (JWT auth, port 8551)
    v
[op-reth]  ← new: replaces op-geth
    |
    | JSON-RPC
    v
dApps / follower queries
```

### Docker image

```bash
# Official OP Labs op-reth image
docker pull us-docker.pkg.dev/oplabs-tools-artifacts/images/op-reth:latest
# or build from source:
git clone https://github.com/paradigmxyz/reth
cd reth && cargo build --release --features optimism --bin op-reth
```

### Init (replaces op-geth init)

```bash
# op-reth init requires genesis in reth format
# reth can import op-geth genesis.json directly:
op-reth init --datadir ./data/reth \
    --chain ./genesis.json \
    --rollup.config ./rollup.json
```

### Start op-reth (follower)

```bash
op-reth node \
    --datadir ./data/reth \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --authrpc.jwtsecret ./jwt.txt \
    --http --http.addr 127.0.0.1 --http.port 9546 \
    --http.api eth,net,web3,debug \
    --port 30304 \
    --rollup.sequencer-http http://141.11.156.4:9545 \
    --disable-discovery
```

### op-node side — unchanged

op-node connects to op-reth via Engine API exactly like op-geth:
```bash
op-node \
    --l2=http://127.0.0.1:8551 \
    --l2.jwt-secret=./jwt.txt \
    --rollup.config=./rollup.json \
    ... (all other flags same)
```

---

## Makefile additions (Midterm 2 targets)

Will add to the existing Makefile:
```makefile
RETH_IMG ?= us-docker.pkg.dev/oplabs-tools-artifacts/images/op-reth:latest
RETH_DATA := $(DIR)/data/reth

make reth-init     # init reth datadir with genesis.json
make reth-up       # start op-reth + op-node (follower)
make reth-status   # query syncStatus from reth-backed node
make reth-bench    # compare block-sync speed reth vs geth
make reth-down     # stop reth containers
```

---

## Implementation Plan (PR milestones)

| PR | Content |
|---|---|
| PR-1 (this) | Makefile (op-geth deploy, step-by-step) |
| PR-2 | Midterm 2: reth-targets in Makefile + reth init/start verified |
| PR-3 | Benchmark: reth vs geth sync speed on Nova L2 |
| PR-4 | (stretch) op-reth + op-node on sequencer |

---

## Known risks

1. **genesis.json format** — op-reth may need the genesis in a slightly different format
   than op-geth. Will test and document the diff.
2. **op-reth version pinning** — reth moves fast; will pin to a known-good tag.
3. **exex pipeline** — op-reth's execution extension system is powerful but docs sparse.
   Will start without exex, add later.

---

## What's proven today (before Midterm 2 build)

- [x] Makefile written (PR-1) — 10-step deploy, follower + sequencer, bridge-in, bridge-out
- [x] Canonical genesis confirmed: `0x1c9445c6` (multi-oracle consensus)
- [x] L1 derivation working: safe_l2=3796, finalized_l2=3191
- [x] P2P sync working: unsafe blocks to 3740+
- [ ] op-reth init — pending (PR-2)
- [ ] op-reth follower running on Nova L2 — pending (PR-2)

Will update Issue with each step.
