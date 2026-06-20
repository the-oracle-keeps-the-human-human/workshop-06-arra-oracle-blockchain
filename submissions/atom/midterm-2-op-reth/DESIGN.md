# Atom Midterm 2 Design — OP Stack deploy Makefile with op-reth path

## Goal

Make a repeatable, reviewable deployment script for a real OP Stack L2 node. The submission is a Makefile because the class needs visible steps, not a hidden one-shot shell script.

## Design choices

- `op-reth` is the target client-diversity path, but it must be given a reth-compatible chain spec via `OP_RETH_CHAIN`.
- `op-geth` remains as `EXEC_CLIENT=op-geth` only for compatibility with the workshop machines.
- `op-node` is always paired 1:1 with one execution client.
- No private key, JWT, or funded signer is committed.
- Runtime data stays under `run/`, which is ignored by Git.
- Public config is downloaded from `CONFIG_BASE`, but every value is overrideable.
- The Makefile refuses stale `rollup.json` when `.genesis.l2.hash` does not match `EXPECTED_L2_GENESIS`.

## Workflow

```bash
cd submissions/atom/midterm-2-op-reth
cp .env.example .env.local
make preflight
make fetch-config
make jwt
make run-exec      # terminal 1
make run-node      # terminal 2
make verify
```

## What this proves

- L1 derivation: `op-node` reads L1 + beacon and advances `safe_l2` / `finalized_l2`.
- L2 P2P: `op-node` can follow unsafe blocks from a sequencer peer when `SEQUENCER_MULTIADDR` is set.
- Bridge readiness: once L1 derivation works, deposits can be observed on L2 after the normal delay.
- Client diversity: the Makefile makes `op-reth` the first-class path while preserving an `op-geth` fallback.

## Known ceiling

This does not deploy L1 contracts from scratch yet. It starts from an existing `genesis.json` + `rollup.json` bundle. Add `op-deployer` targets when the assignment requires full chain genesis creation, not just node deployment.

## Reference

- Optimism execution client configuration: https://docs.optimism.io/node-operators/guides/configuration/execution-clients
- `op-reth` requires a reth-compatible `--chain` value; `rollup.json` is not used as a fake chain spec.
