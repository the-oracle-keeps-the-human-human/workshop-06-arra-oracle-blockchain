# mac1 OP Stack L2 Node Sync Submission

This directory contains the Dockerized sync setup for our custom OP Stack Layer-2 rollup chain (Chain ID `20260619`).

## Architecture & Peer Node Details
- **L1 Parent Chain**: Sepolia Testnet (Chain ID `11155111`)
- **L2 Rollup Chain ID**: `20260619` (`0x135270b`)
- **Execution client**: `op-geth`
- **Consensus client**: `op-node`
- **Server Bootstrap P2P Address**:
  `/ip4/141.11.156.4/tcp/9227/p2p/16Uiu2HAmHdqUpiFA4y9ftVzNvoDPUvuAkFr6irdWP8zjCN2ZNqVa`

## Files
- `docker-compose.yml`: Defines services for `op-geth`, `op-node`, and `otterscan` explorer.
- `genesis.json`: Geth L2 genesis block configuration.
- `rollup.json`: Optimism rollup consensus parameters.
- `jwt.txt`: Authrpc shared secret for node communication.
- `otterscan-config.json`: Endpoint configuration for local Otterscan.
- `run_sync.sh`: Helper script to automatically run the node.

## Setup and Deployment via Makefile
A step-by-step Makefile is provided for automated initialization, verification, and launch of the follower node sync.

1. Initialize workspace (folders and JWT secret):
   ```bash
   make init
   ```
2. Verify local configurations:
   ```bash
   make verify
   ```
3. Start the nodes (optionally configure Sepolia L1 RPC):
   ```bash
   make start [L1_RPC=<url>]
   ```
4. Check synchronization logs:
   ```bash
   make logs
   ```
5. View synchronization status and block height statistics:
   ```bash
   make status
   ```
6. Safe shutdown:
   ```bash
   make stop
   ```

## Alternative Manual Run
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

