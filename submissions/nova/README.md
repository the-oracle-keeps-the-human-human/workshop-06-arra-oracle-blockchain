# Nova 🔮 — OP Stack L2 · Workshop 06

## Architecture
```
L1: Sepolia Testnet (11155111)
    |
    +-- op-deployer v0.7.0-rc.1 -> deploy L1 contracts
    |
L2: OP Stack Chain (20260619)
    |
    +-- op-geth v1.101702.2 (execution, 85MB, Go 1.24)
    +-- op-node v0.0.0-dev (consensus, 73MB, Go 1.24)
    |
    +-- ERC-4337 Paymaster
         +-- TokenPaymaster: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
         +-- NovaToken (NOVA): 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

## L1 Contracts (Sepolia)
Deployed via `op-deployer apply` — Sepolia L1

| Role | Address | ETH |
|---|---|---|
| Admin/Owner | 0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A | 2.60 |
| Sequencer | 0xC65BBCa5851aC0d1Cd347aF0e61Cd1F053a20Dc5 | 0.05 |
| Batcher | 0xD8f504D1b96447d951f08C93CFeDFD378Db91a26 | 0.05 |
| Proposer | 0xdF7345D25A9Ca6bDB879EAa48974c82eF58935A7 | 0.05 |

## L2 Genesis
- Hash: 0xd5fff5ddf838f0a4dcc0ff35e679aa7d79a34ec01e3f7e2b9f23ce621373ac2d
- Forks: Bedrock + Canyon + Ecotone + Fjord + Granite + Holocene + Isthmus
- 2343 predeploys (EntryPoint v0.6/v0.7, Safe, MultiCall3, Permit2, etc.)

## Build From Source
```bash
# Build op-geth
git clone --depth 1 https://github.com/ethereum-optimism/op-geth
cd op-geth && go run build/ci.go install ./cmd/geth

# Build op-node
git clone --depth 1 https://github.com/ethereum-optimism/optimism
cd optimism/op-node && go build -o ../../op-node ./cmd/
```

## Run (op-geth + op-node)
```bash
# Generate genesis + rollup
op-deployer inspect genesis --workdir deployer-workdir 20260619 > genesis.json
op-deployer inspect rollup  --workdir deployer-workdir 20260619 > rollup.json
openssl rand -hex 32 > jwt.txt

# Init and start op-geth
op-geth init --datadir data genesis.json
op-geth --datadir data --networkid 20260619 \
  --http --http.addr 0.0.0.0 --http.port 8555 --http.api eth,net,web3 \
  --authrpc.addr 0.0.0.0 --authrpc.port 8664 --authrpc.jwtsecret jwt.txt \
  --port 30315 --nodiscover &

# Start op-node (derives L2 from L1 Sepolia)
op-node \
  --l2=http://127.0.0.1:8664 --l2.jwt-secret=jwt.txt --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json --rpc.addr=0.0.0.0 --rpc.port 8655 &
```

## Verify
```bash
curl localhost:8555 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# -> 0x135270b (20260619)

curl localhost:8655 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'
# -> L1 connected, L2 deriving
```

## Live Proof
- op-geth + op-node connected via Engine API (JWT)
- op-node deriving from Sepolia L1 (block 11092768+)
- L1 contracts deployed on Sepolia testnet
- Live RPC: http://141.11.156.4:8555

## Repo
https://github.com/anupob88/nova-sepolia-paymaster

-- Nova · Workshop 06 · 2026-06-19
