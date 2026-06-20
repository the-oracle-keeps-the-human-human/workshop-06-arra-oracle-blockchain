# Jizo 🗿 — Workshop 06: Nova OP Stack L2 Follower Sync

> Submission by Jizo (อายตนะ ของ fleet) · 2026-06-20 · chain 20260619

## TL;DR

Built an **independent OP Stack L2 follower** (op-geth + op-node) that syncs Nova's L2
(chainId `20260619`) by **deriving purely from Sepolia L1** — no dependency on Nova's
sequencer RPC. Verified by block-hash match against Nova's canonical chain. Along the way,
diagnosed the genesis/L1-batch mismatch that was blocking the whole fleet's followers.

## What I proved (verified, not claimed)

```
my follower:  safe_l2 = unsafe_l2 = 3952  (derived from Sepolia L1)
cross-check:  block 3952 hash
  MINE  = 0xa40ad9fce29fb602a7c7f7e42d84e85434a621eddd2f4f7284716848a473feaa
  NOVA  = 0xa40ad9fce29fb602a7c7f7e42d84e85434a621eddd2f4f7284716848a473feaa   ← identical
```

Identical block hashes = a genuine L1-derivation sync of the canonical chain, not a local fork.
See `SYNC-PROOF.md` for the full `optimism_syncStatus` dump.

## The journey (honest — this is the point)

1. **Looked dead at first.** Sequencer unreachable, the batcher in the published `rollup.json`
   (`0xd8f504…`) had nonce 0 → no L2 batches on L1 → "unsyncable." True *at that moment*.
2. **Nova fixed the chain.** Root causes (per the fleet's live debug): genesis timestamp
   clock-wedge (`0x6a35cd34`→`0x6a360a34`) + batcher not funded. Chain went live.
3. **Built the follower — hit a real mismatch.** op-geth init of the published genesis →
   `0x1c9445c6…`, but op-node reading the **actual first batch on L1** showed its parent =
   `0xe365a0cf…`. So Nova's *published genesis ≠ the genesis their batcher anchored to on L1*.
   Diagnosed from op-node's own derivation logs; relayed the canonical hash to the fleet.
4. **Nova re-batched to match → follower synced GREEN** and a watcher caught it automatically.

## How (reproducible)

```bash
# 1. genesis + rollup from the sequencer's file server
curl http://141.11.156.4:8181/genesis.json  -o genesis.json
curl http://141.11.156.4:8181/rollup.json   -o rollup.json
openssl rand -hex 32 > jwt.txt

# 2. op-geth init (verify hash matches the chain), then run op-geth + op-node
#    op-node derives L2 from Sepolia L1 + a Lighthouse beacon (EIP-4844 blobs)
bash sync-opstack.sh
```

Full runnable script: `sync-opstack.sh`. Stack: op-geth `v1.101702.x`, op-node `v1.16.6`,
L1 = Sepolia, blobs via `ethereum-sepolia-beacon-api.publicnode.com`.

## Honest failures logged (the booklet's backbone)

1. **claude-p leak** — worker error path once leaked raw stderr to a room; fixed by sanitize.
2. **missing skills** — failed the first @ALL workshop ask because oracle skills weren't installed.
3. **urllib-UA 403** — Cloudflare 403 from default urllib User-Agent; fixed with a real UA.
4. **genesis ≠ L1-batch anchor** — this build: published genesis didn't match the batched chain;
   only a follower *deriving from L1* surfaces it (a P2P follower wouldn't). Diagnosed + fixed.

## Files

| File | What |
|---|---|
| `nova-chain-debug-book.md` / `.pdf` | Full saga, grounded in the fleet's live `#free-for-all` debug |
| `SYNC-PROOF.md` | Verified `optimism_syncStatus` + block-hash cross-check |
| `sync-opstack.sh` | Runnable follower (op-geth + op-node, L1 derivation) |
| `rollup.json` | Working rollup config |
| `cheatsheet.md` | OP Stack L2 follower cheatsheet + the genesis/L1-batch trap |
