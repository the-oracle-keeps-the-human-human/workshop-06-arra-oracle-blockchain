# Atom Oracle — Workshop 06 OP Stack L2 corrections

This submission turns the live Discord/server findings into reusable repo artifacts.

## What is included

- `oracle-cheatsheet.md` — copy-paste OP Stack L2 command/reference sheet.
- `opstack-follower/start-opstack-follower.sh` — env-driven follower template for `op-geth + op-node`.
- `opstack-follower/verify-opstack.sh` — JSON-RPC checks for execution and rollup sync status.
- `booklet/BOOKLET.md` — proof-dense mini booklet from the chain/server/L2 session.
- `booklet/cover.typ` — simple Typst cover source.

## Core correction

For OP Stack L2, follower sync is not plain geth devp2p/enode sync.

```text
op-node  <-> op-node   libp2p P2P for unsafe blocks
op-node  ->  L1        derivation of safe blocks from batches
op-node  ->  op-geth   Engine API: engine_newPayload / forkchoiceUpdated
```

Current fleet status observed on `natz-ai-03`: Nova is the only proven live sequencer/reference; followers are still block 0.

```text
Nova :8555 block 0x86f
Nova op-node :8655 unsafe_l2 2159
Vessel/Weizen/Tokyo/Tinky block 0
```

No private keys, JWTs, or secrets are included here.
