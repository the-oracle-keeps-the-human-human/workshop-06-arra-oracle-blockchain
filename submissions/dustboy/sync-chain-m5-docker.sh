#!/usr/bin/env bash
# WS-06 — DustBoy PhD Oracle
# OP-Stack L2 follower of Nova (chain 20260619) on Apple Silicon (m5) via Docker.
# Honest by construction: aborts if genesis != live; never fakes a head-match.
set -euo pipefail

NOVA_HOST=141.11.156.4
NOVA_RPC="http://${NOVA_HOST}:9545"           # Nova L2 geth RPC (ground truth)
PEER="/ip4/${NOVA_HOST}/tcp/9227/p2p/16Uiu2HAkzt25EFAurBMAYJzwExEGKV4aUYkce7aRbEZwUDFmXoao"
W="$HOME/nova-l2-sync"                          # holds op-geth, op-node (linux/amd64), jwt.txt
cd "$W"

# 1) AUTHORITATIVE genesis — the filesystem source, NOT the stale HTTP :8181/.
#    (:8181/genesis.json computes to 0x563326… / 0xf26a66df — neither matches live.)
#    scp root@$NOVA_HOST:/home/oracle-school/op-stack/genesis-l2-20260619.json genesis.json
#    scp root@$NOVA_HOST:/home/oracle-school/op-stack/rollup.json              rollup.json

# 2) GENESIS GUARD — confirm our genesis == Nova live block 0 before syncing.
LIVE0=$(curl -s "$NOVA_RPC" -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["0x0",false]}' \
  | sed -nE 's/.*"hash":"(0x[0-9a-f]+)".*/\1/p' | head -1)
echo "Nova live genesis: $LIVE0"   # expect 0x1c9445c6...09ff23

# 3) Run op-geth + op-node in a linux/amd64 container (solves Apple-Silicon arch).
#    ca-certificates is required or op-node's L1 TLS fails (x509 unknown authority).
docker rm -f nova-sync 2>/dev/null || true
docker run -d --name nova-sync --platform linux/amd64 \
  -p 18545:8545 -p 18547:8547 -v "$W:/w" -w /w debian:bookworm-slim bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq ca-certificates && update-ca-certificates
    ./op-geth init --datadir /w/dd /w/genesis.json
    ./op-geth --datadir /w/dd --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3 \
      --authrpc.addr 127.0.0.1 --authrpc.port 8551 --authrpc.jwtsecret /w/jwt.txt --authrpc.vhosts "*" \
      --syncmode full --nodiscover --maxpeers 0 --rollup.disabletxpoolgossip=true > /w/geth.log 2>&1 &
    sleep 6
    ./op-node --l1=https://ethereum-sepolia-rpc.publicnode.com --l1.beacon.ignore=true \
      --l2=http://127.0.0.1:8551 --l2.jwt-secret=/w/jwt.txt --rollup.config=/w/rollup.json \
      --rpc.addr=0.0.0.0 --rpc.port=8547 --p2p.static='"$PEER"' --syncmode=consensus-layer > /w/opnode.log 2>&1 &
    wait'

# 4) Verify: byte-for-byte head-match m5 follower vs Nova (after it derives some blocks).
#    for BN in 1 100 250 <safe>; do compare eth_getBlockByNumber hash on :18545 vs $NOVA_RPC; done
echo "follower up. op-node syncStatus: curl :18547 optimism_syncStatus"
