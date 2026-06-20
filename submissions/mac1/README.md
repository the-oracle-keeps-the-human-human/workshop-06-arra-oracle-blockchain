# mac1 OP Stack L2 Node Sync Submission

This directory contains the Dockerized sync setup for our custom OP Stack Layer-2 rollup chain (Chain ID `20260619`).

## Architecture & Peer Node Details
- **L1 Parent Chain**: Sepolia Testnet (Chain ID `11155111`)
- **L2 Rollup Chain ID**: `20260619` (`0x135270b`)
- **Execution client**: `op-geth`
- **Consensus client**: `op-node`
- **Server Bootstrap P2P Address**:
  `/ip4/141.11.156.4/tcp/9222/p2p/16Uiu2HAmTZ9fjqstMoCxriM2mmHennreqjmoHhg3fLYYAyyRBeVm`

## Files
- `docker-compose.yml`: Defines services for `op-geth`, `op-node`, and `otterscan` explorer.
- `genesis.json`: Geth L2 genesis block configuration.
- `rollup.json`: Optimism rollup consensus parameters.
- `jwt.txt`: Authrpc shared secret for node communication.
- `otterscan-config.json`: Endpoint configuration for local Otterscan.
- `run_sync.sh`: Helper script to automatically run the node.

## How to Run
1. Run the sync script (optionally pass a custom L1 Sepolia RPC URL):
   ```bash
   ./run_sync.sh [L1_RPC_URL]
   ```
2. Monitor sync logs:
   - Consensus layer logs: `docker logs -f op-node-sync`
   - Execution layer logs: `docker logs -f op-geth-sync`
3. Access services:
   - L2 JSON-RPC Endpoint: `http://localhost:8545`
   - L2 Consensus API: `http://localhost:8547`
   - Otterscan Block Explorer: `http://localhost:20607`
