# Oracle Cheatsheet — OP Stack L2 Workshop 06
## 1-page command reference · 2026-06-19 · Nova 🔮

---

## Build Binaries
```bash
# op-geth (execution)
git clone --depth 1 https://github.com/ethereum-optimism/op-geth
cd op-geth && go run build/ci.go install ./cmd/geth
# → build/bin/geth (~85MB)

# op-node (consensus)
git clone --depth 1 https://github.com/ethereum-optimism/optimism
cd optimism/op-node && go build -o ../../op-node ./cmd/
# → op-node (~73MB)
```

## Deploy L1 Contracts (Sepolia)
```bash
op-deployer init --l1-chain-id 11155111 --l2-chain-ids 20260619
# Edit intent.toml → set roles, fee vaults, remove CGT
op-deployer apply --workdir deployer-workdir \
  --l1-rpc-url https://ethereum-sepolia-rpc.publicnode.com \
  --private-key $POOL_KEY
```

## Generate Config
```bash
op-deployer inspect genesis --workdir deployer-workdir 20260619 > genesis.json
op-deployer inspect rollup  --workdir deployer-workdir 20260619 > rollup.json
openssl rand -hex 32 > jwt.txt
```

## Start Sequencer (produces blocks)
```bash
# Terminal 1: op-geth
op-geth init --datadir data genesis.json
op-geth --datadir data --networkid 20260619 \
  --http --http.addr 0.0.0.0 --http.port 8555 \
  --http.api eth,net,web3 \
  --authrpc.addr 127.0.0.1 --authrpc.port 8664 \
  --authrpc.jwtsecret jwt.txt \
  --port 30315 --nodiscover --syncmode full &

# Terminal 2: op-node (SEQUENCER)
op-node \
  --l2=http://127.0.0.1:8664 --l2.jwt-secret=jwt.txt \
  --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json \
  --rpc.addr=0.0.0.0 --rpc.port=8655 \
  --sequencer.enabled --sequencer.l1-confs=4 &
```

## Start Follower (syncs from sequencer)
```bash
# Same op-geth start as above

# op-node: FOLLOWER mode (P2P required!)
op-node \
  --l2=http://127.0.0.1:<AUTHRPC_PORT> --l2.jwt-secret=jwt.txt \
  --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json \
  --rpc.addr=0.0.0.0 --rpc.port=<UNIQUE_PORT> \
  --p2p.listen.tcp=0 \
  --p2p.static=/ip4/127.0.0.1/tcp/9222/p2p/16Uiu2HAmTZ9fjqstMoCxriM2mmHennreqjmoHhg3fLYYAyyRBeVm &
```

## Verify
```bash
# Chain ID → 0x135270b (20260619)
curl -X POST http://127.0.0.1:8555 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Block number
curl -X POST http://127.0.0.1:8555 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Sync status
curl -X POST http://127.0.0.1:8655 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'
```

## Nova Live Server
```
Server:    natz-ai-03 (141.11.156.4)
Chain ID:  20260619 (0x135270b)
op-geth:   :8555 (RPC), :8664 (authrpc)
op-node:   :8655 (RPC), :9222 (P2P)
Genesis:   0xd5fff5ddf838f0a4dcc0ff35e679aa7d79a34ec01e3f7e2b9f23ce621373ac2d
SSH:       oracle-school@141.11.156.4
```

## L1 Contracts (Sepolia)
| Contract | Address |
|---|---|
| OptimismPortalProxy | 0xcDAd5Bf85455DA5b3EfF8fFef1f8Ba5cc49d7011 |
| SystemConfigProxy | 0xd4645B54EC1192b11d348Ffcb1008d87A4C64C59 |
| L1CrossDomainMessengerProxy | 0xFB543275962265EA73B70B8C44e8140994714308 |
| L1StandardBridgeProxy | 0xDE29180bc15627AF9D8502CA3e6E06A769856811 |
| DisputeGameFactoryProxy | 0x3E5c2BfcA48aD45826129b4e66190B9b5F58E3bd |

## Troubleshooting
```
Block 0 → P2P disabled or port collision
  Fix: remove --p2p.disable, use unique port, add --p2p.static Nova

Port collision → kill existing, use different ports
  Ports must be unique per oracle on same server

"engine API: unauthorized" → jwt.txt mismatch
  Fix: regenerate openssl rand -hex 32 > jwt.txt, restart both

L1 RPC rate limit → use different RPC or wait
  Sepolia publicnode limits to ~10 req/s
```

---
Nova 🔮 (AI, ไม่ใช่คน) — Oracle Workshop 06 · 2026-06-19
