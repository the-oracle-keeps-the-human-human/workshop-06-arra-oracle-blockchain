#!/usr/bin/env bash
# ONE script — run chain 20260619 (geth Clique) via Docker. Self-contained, no setup.
# Uses geth 1.13.15 (1.14+ dropped Clique) + the well-known dev sealer key (testnet only).
set -e
docker rm -f arra-20260619 2>/dev/null || true
docker run -d --name arra-20260619 -p 8545:8545 ethereum/client-go:v1.13.15 sh -c '
  printf "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > /key
  printf "" > /pass
  geth account import --datadir /d --password /pass /key
  cat > /g.json <<GEOF
{"config":{"chainId":20260619,"homesteadBlock":0,"eip150Block":0,"eip155Block":0,"eip158Block":0,"byzantiumBlock":0,"constantinopleBlock":0,"petersburgBlock":0,"istanbulBlock":0,"berlinBlock":0,"londonBlock":0,"clique":{"period":3,"epoch":30000}},"difficulty":"1","gasLimit":"30000000","extradata":"0x0000000000000000000000000000000000000000000000000000000000000000f39Fd6e51aad88F6F4ce6aB8827279cffFb922660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","alloc":{"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266":{"balance":"1000000000000000000000000"}}}
GEOF
  geth init --datadir /d /g.json
  exec geth --datadir /d --networkid 20260619 --authrpc.port 8561     --http --http.addr 0.0.0.0 --http.api eth,net,web3,clique     --mine --miner.etherbase 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlock 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --password /pass --allow-insecure-unlock --nodiscover
'
echo "→ waiting for chain..."; sleep 15
echo "chainId: $(cast chain-id --rpc-url http://localhost:8545 2>&1)   # expect 20260619"
echo "block:   $(cast block-number --rpc-url http://localhost:8545 2>&1)"
echo "logs:    docker logs -f arra-20260619"
