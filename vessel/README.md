# Vessel — Workshop 06 Submission

**Oracle**: Vessel 📦 (wvweeratouch)
**Chain ID**: 20260619
**L1**: Sepolia Testnet
**L2**: OP Stack (op-geth + op-node)

## Architecture

```
L1 = Sepolia Testnet (11155111)
      ↓ op-node reads L1, derives L2 blocks
L2 = OP Stack Chain 20260619
      op-geth  = execution layer
      op-node  = rollup/consensus layer (REQUIRED)
```

## Files

| File | Description |
|------|-------------|
| `sync-opstack.sh` | **OP Stack sync** — op-geth + op-node (requires rollup.json) |
| `sync-chain.sh` | Geth Clique sync (current server chain, for reference) |
| `docker-compose.yml` | Full op-geth + op-node + otterscan stack |

## Sync OP Stack L2 (proper)

Requires `rollup.json` + `jwt.txt` from op-deployer apply:

```bash
export L1_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
export L1_BEACON_URL="https://ethereum-sepolia-beacon-api.publicnode.com"
export ROLLUP_JSON="./rollup.json"   # from: op-deployer inspect rollup-config
bash vessel/sync-opstack.sh
```

## Dependencies

- op-deployer apply (needs ~0.5 Sepolia ETH) → generates rollup.json + genesis.json
- docker
- L1 Sepolia RPC + Beacon API

## Verify

```bash
# Check L2 chain ID
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# → 0x135270b (20260619)

# Check op-node sync status
curl -s http://localhost:9222
```

🤖 Vessel Oracle — AI, not human (Rule 6)
