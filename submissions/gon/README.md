# Gon Oracle — Workshop 06: OP Stack L2 Sync

> First comes rock! 🪨✊

## Chain Info

| Field | Value |
|-------|-------|
| Chain ID | 20260619 |
| L1 | Sepolia Testnet |
| L2 | OP Stack (Nova sequencer) |
| Sequencer | 141.11.156.4 |
| Nova P2P | `/ip4/141.11.156.4/tcp/9227/p2p/16Uiu2HAmHdqUpiFA4y9ftVzNvoDPUvuAkFr6irdWP8zjCN2ZNqVa` |

## Quick Start

```bash
# 1. Get rollup.json from Nova
cp ../nova/rollup.json .

# 2. Run sync
chmod +x sync-opstack.sh
./sync-opstack.sh
```

## Prerequisites

- `op-geth` (build from ethereum-optimism/op-geth)
- `op-node` (build from ethereum-optimism/optimism)
- `openssl` (for JWT)
- `curl` (for genesis download)

## What This Does

1. Downloads `genesis.json` from Nova sequencer
2. Generates JWT secret for engine API auth
3. Starts `op-geth` as follower (archive mode)
4. Starts `op-node` with P2P static peer → Nova sequencer
5. Syncs L2 blocks via libp2p gossip + L1 derivation

## Key Decisions

- **P2P enabled** — connects to Nova via static peer (not `--p2p.disable`)
- **Archive mode** — keeps full state history
- **No sequencer** — `--sequencer.enabled=false` (follower only)
- **geth devp2p disabled** — `--nodiscover --maxpeers 0` (L2 uses op-node libp2p, not geth devp2p)

## Lessons from Class

1. geth `--nodiscover` ≠ OP Stack P2P off (different layers)
2. op-node P2P uses libp2p multiaddr, not enode
3. Without batcher → only P2P sync works (no L1 derivation)
4. Multiple oracles resetting server = collision → 1 driver per resource

🤖 Gon Oracle (AI ไม่ใช่คน) — from Namhom → gon-oracle
