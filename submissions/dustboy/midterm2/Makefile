# Midterm #2 — DustBoy PhD Oracle
# op-reth (reth-family EL, Rust) OP-Stack follower of Nova (chain 20260619)
# Step-by-step. Honest-by-construction: verify-genesis aborts if != live block 0.
# Runs on Apple Silicon via docker --platform linux/amd64.

NOVA_HOST    ?= 141.11.156.4
NOVA_RPC     ?= http://$(NOVA_HOST):9545
NOVA_PEER    ?= /ip4/$(NOVA_HOST)/tcp/9227/p2p/16Uiu2HAkzt25EFAurBMAYJzwExEGKV4aUYkce7aRbEZwUDFmXoao
CANON_GENESIS?= 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
RETH_IMG     ?= ghcr.io/paradigmxyz/op-reth:latest
W            ?= $(HOME)/nova-reth-sync
OPNODE_DIR   ?= $(HOME)/nova-l2-sync        # holds linux/amd64 op-node binary
NET          ?= nova-reth-net
PLAT         := --platform linux/amd64

.PHONY: all deps config verify-genesis init up-reth up-node up status headmatch explorer down clean

all: deps config verify-genesis init up status headmatch ## full pipeline

deps: ## pull op-reth image + create network + check op-node binary
	docker pull $(PLAT) $(RETH_IMG)
	docker network create $(NET) 2>/dev/null || true
	@test -x "$(OPNODE_DIR)/op-node" && echo "op-node binary OK" || echo "WARN: need $(OPNODE_DIR)/op-node (linux/amd64)"

config: ## fetch AUTHORITATIVE genesis+rollup from filesystem source (NOT stale :8181)
	@echo "scp the canonical files from the chain host filesystem:"
	@echo "  scp root@$(NOVA_HOST):/home/oracle-school/op-stack/genesis-l2-20260619.json $(W)/genesis.json"
	@echo "  scp root@$(NOVA_HOST):/home/oracle-school/op-stack/rollup.json              $(W)/rollup.json"
	@test -f "$(W)/genesis.json" && test -f "$(W)/rollup.json" && test -f "$(W)/jwt.txt" && echo "configs present" || (echo "MISSING configs in $(W)"; exit 1)

verify-genesis: ## GUARD — op-reth genesis hash must == Nova live block 0, else abort (honest-by-construction)
	@LIVE=$$(curl -s $(NOVA_RPC) -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["0x0",false]}' | sed -nE 's/.*"hash":"(0x[0-9a-f]+)".*/\1/p'); \
	COMPUTED=$$(docker run --rm $(PLAT) -v "$(W):/w" $(RETH_IMG) init --chain /w/genesis.json --datadir /tmp/guard 2>&1 | sed -nE 's/.*hash=(0x[0-9a-f]+).*/\1/p' | head -1); \
	echo "live=$$LIVE"; echo "reth=$$COMPUTED"; echo "canon=$(CANON_GENESIS)"; \
	if [ "$$COMPUTED" = "$$LIVE" ] && [ "$$COMPUTED" = "$(CANON_GENESIS)" ]; then echo "✅ GENESIS OK"; else echo "❌ GENESIS MISMATCH — ABORT (won't sync wrong chain)"; exit 1; fi

init: ## op-reth init datadir with canonical genesis
	docker run --rm $(PLAT) -v "$(W):/w" $(RETH_IMG) init --chain /w/genesis.json --datadir /w/dd

up-reth: ## run op-reth EL (Engine API :8551, HTTP :8545→host 38545)
	docker rm -f reth-el 2>/dev/null || true
	docker run -d --name reth-el $(PLAT) --network $(NET) -p 38545:8545 -v "$(W):/w" $(RETH_IMG) \
	  node --chain /w/genesis.json --datadir /w/dd \
	  --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /w/jwt.txt \
	  --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3 --http.corsdomain '*' \
	  --disable-discovery --rollup.disable-tx-pool-gossip

up-node: ## run op-node CL (derives L1 + Nova P2P) → drives op-reth
	docker rm -f reth-node 2>/dev/null || true
	docker run -d --name reth-node $(PLAT) --network $(NET) -p 38547:8547 \
	  -v "$(OPNODE_DIR):/n" -v "$(W):/w" -w /n debian:bookworm-slim bash -c '\
	    export DEBIAN_FRONTEND=noninteractive; \
	    apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq ca-certificates >/dev/null 2>&1; \
	    /n/op-node --l1=https://ethereum-sepolia-rpc.publicnode.com --l1.beacon.ignore=true \
	      --l2=http://reth-el:8551 --l2.jwt-secret=/w/jwt.txt --rollup.config=/w/rollup.json \
	      --rpc.addr=0.0.0.0 --rpc.port=8547 --p2p.static=$(NOVA_PEER) --syncmode=consensus-layer'

up: up-reth ## start EL then CL (6s gap for Engine API)
	@sleep 6
	@$(MAKE) up-node

status: ## op-node syncStatus (unsafe/safe/finalized)
	@curl -s -m6 -X POST http://localhost:38547 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | python3 -c "import sys,json;d=json.load(sys.stdin)['result'];print('unsafe',d['unsafe_l2']['number'],'safe',d['safe_l2']['number'],'finalized',d['finalized_l2']['number'],'current_l1',d['current_l1']['number'])"

headmatch: ## byte-for-byte block-hash compare reth-follower vs Nova
	@SAFE=$$(curl -s http://localhost:38547 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | sed -nE 's/.*"safe_l2":\{"hash":"[^"]*","number":([0-9]+).*/\1/p'); \
	echo "reth safe_l2=$$SAFE — comparing 1/100/$$SAFE:"; \
	for BN in 1 100 $$SAFE; do HX=$$(printf 0x%x $$BN); \
	  A=$$(curl -s http://localhost:38545 -H 'content-type: application/json' --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByNumber\",\"params\":[\"$$HX\",false]}" | sed -nE 's/.*"hash":"(0x[0-9a-f]+)".*/\1/p'|head -1); \
	  B=$$(curl -s $(NOVA_RPC) -H 'content-type: application/json' --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByNumber\",\"params\":[\"$$HX\",false]}" | sed -nE 's/.*"hash":"(0x[0-9a-f]+)".*/\1/p'|head -1); \
	  [ -n "$$A" ] && [ "$$A" = "$$B" ] && echo "  block $$BN: ✅ MATCH $$A" || echo "  block $$BN: ❌ reth=$$A nova=$$B"; done

explorer: ## lite block explorer → :8080 (needs op-reth --http.corsdomain '*')
	docker rm -f reth-explorer 2>/dev/null || true
	docker run -d --name reth-explorer $(PLAT) -p 8080:80 -e APP_NODE_URL=http://localhost:38545 alethio/ethereum-lite-explorer
	@echo "open http://localhost:8080"

down: ## stop containers + archive datadir (mv, never rm — Nothing-is-Deleted)
	-docker rm -f reth-el reth-node reth-explorer
	-mv "$(W)/dd" /tmp/reth-dd-archive-$$(date +%s) 2>/dev/null
	@echo "down. datadir archived to /tmp (not deleted)."

clean: down ## alias for down
