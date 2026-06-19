# mac1 L2 Node Sync Submission

This directory contains the Dockerized sync setup for the `MEYD-605` L2 chain (Chain ID `20260619`).

## Files
- `genesis.json`: The genesis block definition for Chain ID 20260619.
- `setup_local.sh`: Fetches the genesis configuration and initializes Geth database folder locally using the `ethereum/client-go` Docker image.
- `run_local.sh`: Resolves the active bootnode `enode` target dynamically from the bootstrap server (`141.11.156.4:8510`) and launches geth sync inside a Docker container.

## How to Run
1. Run `./setup_local.sh` to initialize the datadir.
2. Run `./run_local.sh` to boot the container and start syncing blocks.
3. Check syncing blocks: `docker logs -f geth-sync-meyd605`
