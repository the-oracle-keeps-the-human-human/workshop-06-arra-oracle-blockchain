# Midterm #2 — DustBoy PhD Oracle: op-reth OP-Stack node + Makefile

**op-reth (reth-family, Rust execution client)** syncing **Nova (chain 20260619)** byte-for-byte,
fully automated via a step-by-step `Makefile`. Honest-by-construction (genesis guard). Runs on
**Apple Silicon** via `docker --platform linux/amd64`.

## Why op-reth (the Midterm-2 point: client diversity)

A second client *family* — Rust (reth) vs Go (op-geth) — running the **same** chain proves the
chain is client-agnostic. The block hashes op-reth produced are **identical** to what op-geth
produced (Midterm #1), which is the strongest possible diversity proof.

## Proof — byte-for-byte vs Nova canonical (op-reth EL)

```
op-reth 1.10.2 · safe_l2 920 (via L1 derivation) · vs Nova http://141.11.156.4:9545

block   1: ✅ 0x3b6a77c5a649e71f47a305…   (op-reth == Nova == op-geth)
block 100: ✅ 0x7e90455bf8f344863ba704…   (op-reth == Nova == op-geth)
block 250: ✅ 0x8aa598000f1017a0b4c3bc…   (op-reth == Nova == op-geth)
block 920: ✅ 0xe29e350fa289268f857273…   (op-reth == Nova)
```

`op-reth init --chain genesis.json` → `0x1c9445c6…09ff23` = Nova live block 0 = canonical ✅

## Architecture

```
op-reth (EL, Rust) ──[Engine API + JWT]── op-node (CL) ──┬─ L1 Sepolia (derivation / Path 1)
                                                          └─ Nova P2P static peer (Path 2)
```

## Run (step-by-step Makefile)

```bash
make deps            # pull op-reth image + network + check op-node binary
make config          # fetch authoritative genesis+rollup (filesystem source, NOT stale :8181)
make verify-genesis  # GUARD: op-reth genesis hash == Nova live block 0, else ABORT
make init            # op-reth init datadir
make up              # up-reth (EL) then up-node (CL)
make status          # syncStatus (unsafe/safe/finalized)
make headmatch       # byte-for-byte block-hash compare vs Nova
make explorer        # lite-explorer → :8080
make down            # teardown (mv datadir → /tmp, never rm)
```

## Blockers hit + fixed (carried from Midterm #1 + new)

| blocker | fix |
|---------|-----|
| op-reth image entrypoint already `op-reth` | call `--version`/`init` directly (no double prefix) |
| Linux binary on Apple Silicon | `docker --platform linux/amd64` |
| genesis 3-way mismatch (stale :8181) | filesystem source `genesis-l2-20260619.json` (= live `0x1c9445c6`) |
| op-node L1 TLS `x509 unknown authority` | `apt install ca-certificates` in CL container |
| sync-to-wrong-chain risk | `make verify-genesis` guard aborts unless hash == live |

## Notes
- Path 1 (L1 derivation) proven here. Path 2 (P2P) wired (`--p2p.static`); on Apple-Silicon Docker
  the libp2p outbound dial is NAT-limited (same as Midterm #1) — use a Linux host for live P2P.
- Genesis guard = the chain cannot emit a fake head-match.

🤖 DustBoy PhD Oracle (AI, Rule 6)
