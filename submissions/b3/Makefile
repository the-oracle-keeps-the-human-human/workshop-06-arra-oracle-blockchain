# ───────────────────────────────────────────────────────────────────────────
# ARRA L2 — op-reth follower (Midterm #2, B3 Oracle)
# Step-by-step deploy of a Reth-family OP Stack follower for chain 20260619.
# Run `make` (or `make help`) to see the ordered steps.
# ───────────────────────────────────────────────────────────────────────────
SHELL        := /bin/bash
CHAIN_ID     := 20260619
CANON_GENESIS:= 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
NOVA         := http://141.11.156.4:9545
NODE_RPC     := http://localhost:7647
RETH_RPC     := http://localhost:8645
OPRETH_IMG   := ghcr.io/paradigmxyz/op-reth:latest
export L1_RPC    ?= https://ethereum-sepolia-rpc.publicnode.com
export L1_BEACON ?= https://ethereum-sepolia-beacon-api.publicnode.com

.DEFAULT_GOAL := help

## ── ordered steps ──────────────────────────────────────────────────────────

deps: ## 1. pull images (op-reth Jovian-capable + op-node) — needs docker + cast
	@command -v docker >/dev/null || { echo "❌ docker required"; exit 1; }
	@command -v cast   >/dev/null || { echo "❌ foundry 'cast' required"; exit 1; }
	docker pull $(OPRETH_IMG)
	docker pull us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:latest
	@echo "✅ deps ready"

config: ## 2. ensure genesis.json + rollup.json present (rollup from LIVE op-node, not stale :8181)
	@test -s genesis.json || { echo "❌ vendor genesis.json (must init to $(CANON_GENESIS))"; exit 1; }
	@test -s rollup.json  || { echo "❌ vendor rollup.json (pull from Nova live optimism_rollupConfig)"; exit 1; }
	@echo "✅ config present"

jwt: ## 3. generate shared JWT secret
	@test -s jwt.txt || openssl rand -hex 32 > jwt.txt
	@echo "✅ jwt.txt"

init: jwt ## 4. op-reth init datadir from genesis
	docker run --rm -v $(PWD):/data $(OPRETH_IMG) init --chain /data/genesis.json --datadir /data/datadir
	@echo "✅ initialized"

verify-genesis: ## 5. HARD GATE — op-reth block0 must == Nova live genesis ($(CANON_GENESIS)); else abort
	@mine=$$(docker run --rm -v $(PWD):/data $(OPRETH_IMG) init --chain /data/genesis.json --datadir /data/datadir 2>&1 | grep -oE '0x[0-9a-f]{64}' | head -1); \
	nova=$$(cast block 0 --rpc-url $(NOVA) -f hash 2>/dev/null); \
	echo "  op-reth block0 : $$mine"; echo "  nova   block0 : $$nova"; echo "  expected      : $(CANON_GENESIS)"; \
	if [ "$$mine" = "$(CANON_GENESIS)" ] && [ "$$mine" = "$$nova" ]; then echo "✅ genesis gate PASS"; \
	else echo "❌ genesis MISMATCH — refusing to sync a wrong/dead chain"; exit 1; fi

up-reth: ## 6. start op-reth (EL) — Engine API :8551, http :8645, NO_PROXY baked in
	docker compose up -d op-reth
	@echo "✅ op-reth up (block0 check):"; sleep 6; cast block 0 --rpc-url $(RETH_RPC) -f hash

up-node: ## 7. start op-node (CL) — Path 1 (L1 derive) + Path 2 (P2P static to Nova)
	docker compose up -d op-node
	@echo "✅ op-node up — deriving + dialing Nova P2P"

up: verify-genesis up-reth up-node ## 6+7 combined (after init): gate → EL → CL

status: ## 8. show unsafe/safe/finalized + EL head
	@cast rpc optimism_syncStatus --rpc-url $(NODE_RPC) | python3 -c "import sys,json;d=json.load(sys.stdin);print('unsafe',d['unsafe_l2']['number'],'safe',d['safe_l2']['number'],'finalized',d['finalized_l2']['number'],'L1',d.get('current_l1',{}).get('number'))"
	@echo -n "EL head: "; cast block-number --rpc-url $(RETH_RPC)
	@cast rpc opp2p_peers true --rpc-url $(NODE_RPC) | python3 -c "import sys,json;print('P2P peers:',json.load(sys.stdin).get('totalConnected'))" 2>/dev/null || true

headmatch: ## 9. byte-for-byte block-hash match vs Nova (proof of correct sync)
	@for B in 1 100 1000 $$(cast rpc optimism_syncStatus --rpc-url $(NODE_RPC) | python3 -c "import sys,json;print(json.load(sys.stdin)['safe_l2']['number'])"); do \
	  o=$$(cast block $$B --rpc-url $(RETH_RPC) -f hash 2>/dev/null); n=$$(cast block $$B --rpc-url $(NOVA) -f hash 2>/dev/null); \
	  [ "$$o" = "$$n" ] && echo "  blk $$B  $$o  MATCH ✅" || echo "  blk $$B  ours=$$o nova=$$n  ❌"; \
	done

logs: ## tail op-reth + op-node logs
	docker compose logs -f --tail=40

down: ## teardown — archive datadir to /tmp (Nothing is Deleted), never rm -rf
	docker compose down
	@test -d datadir && mv datadir /tmp/b3-reth-datadir.$$(date +%s) || true
	@echo "✅ down (datadir archived, not deleted)"

help: ## show this ordered step list
	@echo "ARRA L2 op-reth follower — step-by-step:"
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed -E 's/:.*## /\t/' | awk -F'\t' '{printf "  make %-15s %s\n",$$1,$$2}'

.PHONY: deps config jwt init verify-genesis up-reth up-node up status headmatch logs down help
