# Nova 🔮 — OP Stack L2 · Workshop 06

## Status: 🟢 LIVE — Block #327+ (2026-06-19 14:42 UTC+7)

## Architecture
```
L1: Sepolia Testnet (chainId 11155111)
    │
    ├── op-deployer v0.7.0-rc.1 → deploy L1 contracts
    │
L2: OP Stack Chain "Nova L2" (chainId 20260619)
    │
    ├── op-geth v1.101702.2 (execution, :8555)
    ├── op-node v0.0.0-dev  (consensus/sequencer, :8655)
    │
    └── Future: ERC-4337 Paymaster
```

## L1 Contracts Deployed on Sepolia (Real Deployment)
`op-deployer apply` — paid with pool wallet (~0.15 ETH gas), 17+ txs confirmed

| Contract | Address |
|---|---|
| OptimismPortalProxy | `0xcDAd5Bf85455DA5b3EfF8fFef1f8Ba5cc49d7011` |
| SystemConfigProxy | `0xd4645B54EC1192b11d348Ffcb1008d87A4C64C59` |
| L1CrossDomainMessengerProxy | `0xFB543275962265EA73B70B8C44e8140994714308` |
| L1StandardBridgeProxy | `0xDE29180bc15627AF9D8502CA3e6E06A769856811` |
| DisputeGameFactoryProxy | `0x3E5c2BfcA48aD45826129b4e66190B9b5F58E3bd` |
| AnchorStateRegistryProxy | `0x77d8c3E1893fF956E4a0FFa81DdfD8f9c81555Fa` |
| OptimismMintableErc20FactoryProxy | `0xc8a4Df00374a1A6f9fF03341e7877175cd306dd1` |
| L1Erc721BridgeProxy | `0xCCBc057Bd7Ae7aE2aB10D1F3f6606f648e9130E8` |
| AddressManager | `0xF4aD16c880e2d07831c9B5179c2fA7E56ed31baC` |
| OpChainProxyAdmin | `0x2eEa7158262A2aBffe5f2e7b32e801F9fec2ED6e` |
| L1 Start Block | **11092765** |

## L2 Chain — Live
```
Chain ID:   20260619 (0x135270b)
Genesis:    0xd5fff5ddf838f0a4dcc0ff35e679aa7d79a34ec01e3f7e2b9f23ce621373ac2d
Forks:      Bedrock, Canyon, Ecotone, Fjord, Granite, Holocene, Isthmus
Predeploys: 2343 (EntryPoint v0.6/v0.7, Safe, MultiCall3, Permit2, Create2, etc.)
Block time: 2s
Gas limit:  60,000,000
```

## Server (Live)
```
IP:           141.11.156.4
op-geth RPC:  http://141.11.156.4:8555
op-node RPC:  http://141.11.156.4:8655
op-geth P2P:  port 30315
```

## Build From Source (for any machine)
```bash
# Prerequisites: Go 1.24+, git
# Build op-geth
git clone --depth 1 https://github.com/ethereum-optimism/op-geth
cd op-geth && go run build/ci.go install ./cmd/geth
# Binary at: op-geth/build/bin/geth (~85MB)

# Build op-node
git clone --depth 1 https://github.com/ethereum-optimism/optimism
cd optimism/op-node && go build -o ../../op-node ./cmd/
# Binary at: ./op-node (~73MB)
```

## Sync Node Setup (for friends)
```bash
# 1. Get genesis + rollup from us
curl -o genesis.json http://141.11.156.4:8555/genesis.json  # or copy from repo
# rollup.json is in this directory

# 2. Generate JWT
openssl rand -hex 32 > jwt.txt

# 3. Init op-geth
op-geth init --datadir op-geth-data genesis.json

# 4. Start op-geth (execution)
op-geth --datadir op-geth-data --networkid 20260619 \
  --http --http.addr 0.0.0.0 --http.port 8555 --http.api eth,net,web3 \
  --authrpc.addr 127.0.0.1 --authrpc.port 8664 --authrpc.jwtsecret jwt.txt \
  --port 30315 --nodiscover --syncmode full &

# 5. Start op-node (consensus — derives L2 from Sepolia L1)
op-node \
  --l2=http://127.0.0.1:8664 --l2.jwt-secret=jwt.txt --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json --rpc.addr=0.0.0.0 --rpc.port=8655 &
```

## Sequencer Setup (produces blocks)
```bash
# Same as sync, plus sequencer flags on op-node:
op-node \
  --l2=http://127.0.0.1:8664 --l2.jwt-secret=jwt.txt --l2.enginekind=geth \
  --l1=https://ethereum-sepolia-rpc.publicnode.com \
  --l1.beacon=https://ethereum-sepolia-beacon-api.publicnode.com \
  --rollup.config=rollup.json --rpc.addr=0.0.0.0 --rpc.port=8655 \
  --sequencer.enabled --sequencer.l1-confs=4 &
```

## Verify
```bash
# Check chain ID
curl http://141.11.156.4:8555 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# → 0x135270b (20260619)

# Check block number
curl http://141.11.156.4:8555 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
# → 0x147 (327+)

# Check sync status
curl http://141.11.156.4:8655 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'
# → L1 connected, L2 deriving, blocks producing
```

## Proof of Life
```
$ cast block-number --rpc-url http://141.11.156.4:8555
327

$ cast chain-id --rpc-url http://141.11.156.4:8555
20260619

$ cast balance 0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A --rpc-url http://141.11.156.4:8555
0
```

— Nova 🔮 · Workshop 06 · 2026-06-19
