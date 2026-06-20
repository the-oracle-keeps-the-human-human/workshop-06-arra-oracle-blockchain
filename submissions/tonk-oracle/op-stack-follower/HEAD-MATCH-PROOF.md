# WS-06 HEAD-MATCH PROOF — Tonk Oracle 🌿

Generated 2026-06-20T04:37:57Z · follower built from source (op-geth 1.101702.2 + op-node v1.19.0)
Method: **honest L1-derivation** — op-node derived these L2 blocks from L1 Sepolia batches.
Rollup config pulled from Nova's own op-node (`optimism_rollupConfig` @ :9547) to bypass the stale :8181/rollup.json.
NOT a datadir-copy, NOT P2P-trusted — `--syncmode=consensus-layer`, safe head = derived from L1.

## Genesis equality (all three agree)
```
my op-geth block 0 = 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
Nova live block 0  = 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
✅ EQUAL — same chain
```

## Byte-for-byte block hash match (my derived safe head = 1199)
```
block 1     ✅ 0x3b6a77c5a649e71f47a305bdbc670d11d7470bf6a6d088eae71302d53c677952
block 100   ✅ 0x7e90455bf8f344863ba70498c9a21e592285e6beda1994830970443ce4481341
block 300   ✅ 0xb19e38101e799bc0c9491ed98d4705ec89ff2e38ce77d8b55562951a0fa7fd16
block 500   ✅ 0x426ce40eb2ad3a218bba072b41ba961dfb37c4ed5411e95a3e955d5a614fc928
block 1000  ✅ 0x52c9fdf7bba20aaf533be87e23f01d8371541caa5d30725f13ff271ffddd24de
block 1194  ✅ 0xb3ef06a9a16e0efc2be89fa8ab6dccfd2ed3128fc89e1013a97ccc3eb1f73c9c

RESULT: 6/6 byte-for-byte match
```

## Reproduce
```bash
bash build.sh        # op-geth + op-node from source
bash fire-proof.sh   # genesis(:8181) + rollup(Nova optimism_rollupConfig) → derive from L1
# then compare eth_getBlockByNumber on localhost:18780 vs 141.11.156.4:9545
```
