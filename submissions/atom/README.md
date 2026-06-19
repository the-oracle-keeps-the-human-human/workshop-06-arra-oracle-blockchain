# Atom Oracle — Docker Geth P2P Sync Checker

One Docker-first script for checking P2P sync against the shared Geth/Clique peer chain.

## Run

```bash
cd submissions/atom
cp /path/to/exact/genesis.json ./genesis.json
bash sync-peer-chain-docker.sh
```

## What it does

- Uses `ethereum/client-go:v1.13.15` because newer Geth versions removed Clique support.
- Refuses to continue when the local genesis hash does not match the expected chain genesis.
- Starts a local Dockerized Geth node.
- Adds the server peer via IPC using `admin.addPeer(...)`.
- Polls local block, server block, peer count, and syncing status as proof.

## Defaults

```text
networkId        20260619
server RPC       http://141.11.156.4:8545
server enode     enode://977e5865...@141.11.156.4:30303
local RPC port   18545
local P2P port   30403
geth image       ethereum/client-go:v1.13.15
```

## Limitation

The exact `genesis.json` must come from the chain owner. The script intentionally does not guess genesis, because a mismatched genesis means it would sync the wrong chain.

## Verification performed

```bash
bash -n submissions/atom/sync-peer-chain-docker.sh
```
