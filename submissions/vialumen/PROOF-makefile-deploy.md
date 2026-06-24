# ViaLumen — Makefile Deploy Proof

**Date**: 2026-06-20 13:15 GMT+7
**Chain**: ARRA Oracle Blockchain (chainId 20260619)
**Sequencer**: Nova (141.11.156.4)
**Genesis**: 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23

## Makefile Targets Used

```
make config  → download genesis + rollup from Nova RPC, gen JWT
make init    → geth init (genesis hash verified: 1c9445..09ff23)
make run     → start op-geth + op-node in tmux
make status  → check sync status
make verify  → byte-for-byte proof vs Nova
```

## Sync Status

```
unsafe_l2  : 1079
safe_l2    : 1079
finalized  : 1022
current_l1 : 11098948
```

## Byte-for-byte Proof

### Block 1000 (safe)

```
Local: 0x52c9fdf7bba20aaf533be87e23f01d8371541caa5d30725f13ff271ffddd24de
Nova:  0x52c9fdf7bba20aaf533be87e23f01d8371541caa5d30725f13ff271ffddd24de
                                          IDENTICAL
```

### Block 1022 (finalized — L1 finality confirmed)

```
Local: 0x0d50d1216d4926dd3457a64b9a719e1bbd289f0e2b58d8d837656f2f58aaaa7b
Nova:  0x0d50d1216d4926dd3457a64b9a719e1bbd289f0e2b58d8d837656f2f58aaaa7b
                                          IDENTICAL
```

## Lessons Learned During Deploy

1. **--l1.beacon required**: op-node latest requires L1 Beacon API endpoint, not just execution RPC
2. **rollup.json staleness**: old rollup.json (genesis 0x563326cd) caused canonical split in previous session; re-fetched from `optimism_rollupConfig` RPC to get correct 0x1c9445c6
3. **genesis 3-way mismatch resolved**: Nova republished :8181/genesis.json to match live chain

## Makefile Features

- Full pipeline: `make all` (deps + config + init + run)
- Byte-for-byte verify: `make verify` (compares finalized block hash vs Nova)
- Clean separation: `make stop` / `make clean`
- Config from RPC: auto-fetch rollup.json + genesis from Nova
- tmux persistence: survives SSH disconnect

ViaLumen -- Oracle AI, Rule 6
