# ARRA Oracle Chain — `20260619`

PoA (Clique) chain for the oracle network. Genesis + node + Otterscan so peers can **sync**.

## Files
- `genesis.json` — Clique PoA, **chainId 20260619**, period 5s, sealer + class-pool prefunded.
- `docker-compose.yml` — geth node (syncs) + Otterscan explorer.

## Run (friends — to sync the chain)
```bash
# point at the chain host's enode, then bring it up
BOOTNODE="enode://<host-enode>@141.11.156.4:30303" docker compose up -d
# RPC:        http://localhost:8545   (eth_chainId → 0x135270b = 20260619)
# Otterscan:  http://localhost:5100
```

## Verified
- `chainId 20260619` live (`anvil --chain-id 20260619` → `eth_chainId 0x135270b`).
- Otterscan compatibility: `ots_getApiLevel = 8` (via anvil locally).
- genesis.json: valid Clique genesis (extradata vanity+sealer+seal).

## Notes
- Full Otterscan traces need an `ots_`-capable node — swap `ethereum/client-go` →
  `erigontech/erigon` (custom chain from the same `genesis.json`) for complete support.
- School server (`141.11.156.4`): node runs, but non-SSH ports are firewall-blocked
  externally right now → live links pending admin opening ports / reverse proxy.

🤖 ViaLumen ⭐ (AI · Rule 6)

## ⚠️ Otterscan needs **Erigon** (not anvil/geth)
Otterscan checks the `erigon_` namespace (`erigon_getHeaderByNumber`) — pointing it at
anvil/geth gives *"It is an ETH node… does not seem to be an Erigon node"*. For a working
explorer, run the node as **erigon** (custom chain from `genesis.json`, `--http.api=eth,erigon,ots`).
anvil is fine for the chain itself + local sync; only the Otterscan UI needs erigon.

## Local sync (verified ✓)
`./sync-local.sh` — SSH-tunnels the server chain to localhost (firewall-safe).
Verified: `chain-id 20260619`, blocks advancing (28→30, block-time 2s).

## ✅ Working geth Clique node (no funds needed) — `run-geth-clique.sh`
Verified: chainId **20260619**, blocks sealing (3→5, period 3s), enode produced.
**Hard-won lessons** (save these):
- **geth 1.14+ DROPPED Clique/PoW** → `Fatal: only PoS networks are supported`. Use **geth 1.13.x** for PoA.
- Shared host → set a **unique `--authrpc.port`** (default 8551 collides → `address already in use`).
- `--unlock` needs the keystore inside the run datadir (`<datadir>/keystore/`).
