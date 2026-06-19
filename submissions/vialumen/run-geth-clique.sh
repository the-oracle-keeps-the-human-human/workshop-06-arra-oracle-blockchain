#!/usr/bin/env bash
# Run a WORKING geth Clique PoA chain (id 20260619) — no funds, no Sepolia needed.
# Lessons baked in: geth 1.14+ DROPPED Clique (needs PoS) → use geth 1.13.x;
# set a UNIQUE --authrpc.port (shared host collides on default 8551).
set -e
G="${GETH:-$HOME/geth113/geth}"      # must be geth 1.13.x for Clique
D="$HOME/clique-chain"; mkdir -p "$D"; cd "$D"
echo "pass" > pass.txt
[ -f sealer.addr ] || "$G" account new --datadir "$D" --password pass.txt 2>/dev/null | grep -oE '0x[a-fA-F0-9]{40}' | head -1 > sealer.addr
ADDR=$(cat sealer.addr); RAW=${ADDR#0x}
EXTRA="0x$(printf '0%.0s' $(seq 64))${RAW}$(printf '0%.0s' $(seq 130))"
cat > genesis.json <<EOF
{"config":{"chainId":20260619,"homesteadBlock":0,"eip150Block":0,"eip155Block":0,"eip158Block":0,"byzantiumBlock":0,"constantinopleBlock":0,"petersburgBlock":0,"istanbulBlock":0,"berlinBlock":0,"londonBlock":0,"clique":{"period":3,"epoch":30000}},"difficulty":"1","gasLimit":"30000000","extradata":"${EXTRA}","alloc":{"${ADDR}":{"balance":"1000000000000000000000000"}}}
EOF
mkdir -p data113/keystore; cp -n keystore/UTC--* data113/keystore/ 2>/dev/null || true
[ -d data113/geth ] || "$G" init --datadir data113 genesis.json
exec "$G" --datadir data113 --networkid 20260619 --port 30317 --authrpc.port 8561 \
  --http --http.addr 0.0.0.0 --http.port 9630 --http.api eth,net,web3,clique,admin,miner \
  --mine --miner.etherbase "$ADDR" --unlock "$ADDR" --password pass.txt --allow-insecure-unlock --nodiscover
