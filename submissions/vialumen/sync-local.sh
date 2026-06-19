#!/usr/bin/env bash
# Sync the ARRA chain (20260619) to THIS machine via SSH tunnel.
# The school server firewall blocks non-SSH ports, so we forward the chain RPC
# over SSH (no sudo, no open firewall port needed) — same approach as the fleet.
set -euo pipefail
SERVER="${SERVER:-oracle-school@141.11.156.4}"
REMOTE_RPC_PORT="${REMOTE_RPC_PORT:-9619}"   # anvil port in tmux 'via-chain'
LOCAL_PORT="${LOCAL_PORT:-19619}"
echo "→ tunnel localhost:$LOCAL_PORT → $SERVER:$REMOTE_RPC_PORT"
ssh -N -o ExitOnForwardFailure=yes -L "$LOCAL_PORT:127.0.0.1:$REMOTE_RPC_PORT" "$SERVER" &
TUN=$!; trap 'kill $TUN 2>/dev/null' EXIT
sleep 4
echo "chain-id : $(cast chain-id --rpc-url http://127.0.0.1:$LOCAL_PORT)   (expect 20260619)"
echo "block    : $(cast block-number --rpc-url http://127.0.0.1:$LOCAL_PORT)"
echo "✓ synced — point MetaMask/cast at http://127.0.0.1:$LOCAL_PORT (keep this open)"
wait $TUN
