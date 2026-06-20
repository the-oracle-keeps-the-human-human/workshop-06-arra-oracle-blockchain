# WS-06 Midterm #2 — B3 Oracle 🦁

**op-reth (Reth-family, Rust) execution client** following **Nova (chain 20260619)** — byte-for-byte head-match, **both sync paths live**, deployed step-by-step via **Makefile**. Honest by construction.

> B3 was Midterm #1's independent external verifier (proved the original op-geth head-match, caught the OrbStack-502 / op-node-version / genesis-mismatch root causes). Midterm #2 swaps the EL to **op-reth** to prove the chain spec is implementation-independent — not a geth quirk.

## Result — byte-for-byte vs Nova canonical

op-reth follower on **Boom iMac** (independent machine) vs Nova `http://141.11.156.4:9545`:

```
EL = op-reth v1.10.2 (Rust)  |  CL = op-node  |  genesis 0x1c9445c6

block    0: ✅ 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
block    1: ✅ 0x3b6a77c5a649e71f47a305bdbc670d11d7470bf6a6d088eae71302d53c677952
block  100: ✅ 0x7e90455bf8f344863ba70498c9a21e592285e6beda1994830970443ce4481341
block  500: ✅ 0x426ce40eb2ad3a218bba072b41ba961dfb37c4ed5411e95a3e955d5a614fc928
block 1000: ✅ 0x52c9fdf7bba20aaf533be87e23f01d8371541caa5d30725f13ff271ffddd24de
block 1568: ✅ 0xf5a34be8739c02dcf316a3f348bd1366d278ae61221f23e31cb3c6a72dd9d73b
```

A **different EL implementation** (Reth, Rust) reproduced Nova's chain (op-geth, Go) byte-for-byte. Full output in [`proof.txt`](./proof.txt).

## Both sync paths live (stronger than Midterm #1's geth follower)

- **Path 1 — L1 derivation** (`--l1=<sepolia>`): ✅ `safe_l2`/`finalized_l2` derived trustlessly from Sepolia batches.
- **Path 2 — L2 P2P gossip** (`--p2p.static=<nova>`): ✅ connected to Nova's peer (`16Uiu2HAkzt25…`). Midterm #1 had this blocked fleet-wide until Nova added `--p2p.sequencer.key`; it now works, so this follower runs **both paths at once**.

## The op-reth-specific finding (the risk I flagged up front, cleared)

Chain `20260619` runs **Jovian-era** hardforks at genesis (`minBaseFee` / `jovian_time` — the fields that crashed op-node v1.13.5 in Midterm #1). The EL edition of that version wall:

```
op-reth v1.10.2 → forks show "Jovian @0"
$ op-reth init --chain genesis.json
  Genesis block written hash=0x1c9445c6…  ✅  (== Nova live == op-geth init)
```

op-reth's Optimism support already understands Jovian — **no EL version wall**. Pin `op-reth:latest` (≥ v1.10.2); an older build would fail `reth init` on the genesis.

## Honest by construction — the genesis gate

`make verify-genesis` is a **hard gate**: op-reth's `init` block-0 hash **must equal** Nova's live `eth_getBlockByNumber(0)` **and** the canonical `0x1c9445c6`, else the build **aborts**. This makes a fake head-match impossible and prevents the *"republish a dead genesis"* error (an hour before this PR a fleet-mate nearly republished the stale `0xe365a0cf` — a first-batch hash from a dead incarnation; refuted live because `safe_l2`/`finalized_l2` only advance on the genesis the current L1 batches actually anchor).

## Run it (step-by-step Makefile)

```bash
cd submissions/b3
make deps            # pull op-reth + op-node images
make config          # genesis.json + rollup.json present (rollup from LIVE op-node, not stale :8181)
make init            # op-reth init datadir from genesis
make verify-genesis  # HARD GATE: op-reth block0 == Nova live block0 == 0x1c9445c6, else abort
make up-reth         # start op-reth (EL) — Engine API :8551, http :8645, NO_PROXY baked in
make up-node         # start op-node (CL) — Path 1 (L1) + Path 2 (P2P to Nova)
make status          # unsafe/safe/finalized + EL head + P2P peers
make headmatch       # byte-for-byte vs Nova at 1/100/1000/safe
make down            # teardown (datadir archived to /tmp, never rm -rf)
```

Requires Docker + Foundry `cast`. `make help` lists the ordered steps.

## Precautions baked in as defaults (from Midterm #1's 11-problem catalogue)

| # | Precaution | Why |
|---|-----------|-----|
| 1 | `NO_PROXY=*` on every container | OrbStack/Docker-Desktop proxy injection → Engine API 502 |
| 2 | genesis.json **vendored** here | a pruned node can't regenerate genesis; live `:8181` lags redeploys |
| 3 | op-reth pinned ≥ v1.10.2 | must parse Jovian (`minBaseFee`/`jovian_time`) |
| 4 | rollup from live `optimism_rollupConfig` | the stale served file caused the Midterm-1 genesis 3-way mismatch |
| 5 | `verify-genesis` hard gate | cannot emit a fake head-match; blocks the dead-genesis error |
| 6 | `make down` archives, never `rm -rf` | Nothing is Deleted |

---
🦁 **B3 Oracle** — "Lead, don't ask. Deliver, don't suggest." · AI orchestrator, not human (Rule 6)
