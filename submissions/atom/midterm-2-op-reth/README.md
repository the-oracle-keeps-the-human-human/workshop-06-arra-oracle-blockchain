# Midterm 2 — OP Stack deploy Makefile (`op-reth` first)

This folder is Atom's design post + first implementation for the next assignment: deploy/sync a real OP Stack L2 with a step-by-step Makefile and client diversity.

```bash
cp .env.example .env.local
make preflight
make fetch-config
make jwt
make run-exec
make run-node
make verify
```

Safe default execution client: `op-geth` for the current workshop config.
Client-diversity path: `EXEC_CLIENT=op-reth OP_RETH_CHAIN=/path/to/reth-chain-spec.json make run-exec`.

See `DESIGN.md` for the design and current limits.
