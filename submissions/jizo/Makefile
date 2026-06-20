# ─────────────────────────────────────────────────────────────────────────────
# Jizo 🗿 — OP Stack L2 Deploy Makefile
# Chain:  Nova L2  |  chainId 20260619  |  L1: Sepolia (11155111)
# Author: Jizo / Yim  |  2026-06-20
#
# STEPS (in order):
#   1. make check-deps    — verify all tools are present
#   2. make jwt           — generate JWT secret (once per deployment)
#   3. make fetch-genesis — download genesis.json from sequencer
#   4. make init          — initialize op-geth with genesis.json
#   5. make follower-up   — start follower (derive from L1 + P2P from sequencer)
#   OR:
#   5. make seq-up        — run your own sequencer
#   6. make status        — check sync status (safe/unsafe/finalized)
#   7. make bridge-in     — deposit ETH L1→L2 via OptimismPortal
#   8. make bridge-out    — initiate L2→L1 withdrawal
#   9. make stop          — stop all containers
#  10. make clean         — wipe data dirs (IRREVERSIBLE)
# ─────────────────────────────────────────────────────────────────────────────

# ── Image pins ────────────────────────────────────────────────────────────────
OP_GETH_IMG  ?= us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
OP_NODE_IMG  ?= us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:latest

# ── Chain params ──────────────────────────────────────────────────────────────
L2_CHAIN_ID  := 20260619
L1_CHAIN_ID  := 11155111

# ── Sequencer (Nova) ──────────────────────────────────────────────────────────
SEQ_IP       ?= 141.11.156.4
SEQ_RPC_PORT ?= 9545
SEQ_P2P_PORT ?= 9003

# ── L1 RPC (Sepolia) ─────────────────────────────────────────────────────────
L1_RPC       ?= https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON    ?= https://ethereum-sepolia-beacon-api.publicnode.com

# ── L1 contracts (Nova chain, verified on Sepolia) ───────────────────────────
PORTAL_PROXY := 0xcDAd5Bf85455DA5b3EfF8fFef1f8Ba5cc49d7011
BRIDGE_PROXY := 0xDE29180bc15627AF9D8502CA3e6E06A769856811
SYSCFG_PROXY := 0xd4645B54EC1192b11d348Ffcb1008d87A4C64C59

# ── Local paths ───────────────────────────────────────────────────────────────
DIR          := $(shell pwd)
SEQ_DATA     := $(DIR)/data/seq
FOL_DATA     := $(DIR)/data/follower
JWT_FILE     := $(DIR)/jwt.txt
GENESIS      := $(DIR)/genesis.json
ROLLUP       := $(DIR)/rollup.json

# ── Ports (local) ─────────────────────────────────────────────────────────────
SEQ_GETH_HTTP    ?= 9545
SEQ_GETH_AUTH    ?= 9551
SEQ_GETH_P2P     ?= 30303
SEQ_NODE_RPC     ?= 9547
SEQ_NODE_P2P     ?= 9003
FOL_GETH_HTTP    ?= 9546
FOL_GETH_AUTH    ?= 9552
FOL_GETH_P2P     ?= 30304
FOL_NODE_RPC     ?= 9548
FOL_NODE_P2P     ?= 9004

# ── Bridge deposit defaults ───────────────────────────────────────────────────
DEPOSIT_AMOUNT ?= 0.01ether
FROM_ADDR      ?=
PRIVKEY        ?=

.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "  Jizo 🗿 — OP Stack L2 Deploy Makefile   (chain $(L2_CHAIN_ID) on Sepolia)"
	@echo ""
	@echo "  SETUP:"
	@echo "    make check-deps     Check all prerequisites (docker, cast, jq, curl)"
	@echo "    make pull-images    Pull op-geth + op-node Docker images"
	@echo "    make jwt            Generate JWT secret (run once)"
	@echo "    make fetch-genesis  Download genesis.json from sequencer :8181"
	@echo "    make init           Init op-geth data dirs with genesis.json"
	@echo ""
	@echo "  SEQUENCER (run your own — advanced):"
	@echo "    make seq-up         Start sequencer op-geth + op-node"
	@echo "    make seq-down       Stop sequencer containers"
	@echo ""
	@echo "  FOLLOWER (derive + P2P sync from sequencer):"
	@echo "    make follower-up    Start follower op-geth + op-node"
	@echo "    make follower-down  Stop follower containers"
	@echo ""
	@echo "  STATUS:"
	@echo "    make status         Show sync status (safe/unsafe/finalized)"
	@echo "    make logs           Tail follower logs"
	@echo "    make genesis-check  Verify genesis hash vs rollup.json"
	@echo ""
	@echo "  BRIDGE:"
	@echo "    make bridge-in      Deposit ETH L1->L2 (set FROM_ADDR + PRIVKEY)"
	@echo "    make bridge-out     Initiate L2->L1 withdrawal"
	@echo "    make withdrawal-prove     Prove withdrawal on L1"
	@echo "    make withdrawal-finalize  Finalize withdrawal (after 7d challenge)"
	@echo ""
	@echo "  TEARDOWN:"
	@echo "    make stop           Stop all containers"
	@echo "    make clean          Wipe data dirs (IRREVERSIBLE — prompts)"
	@echo "    make clean-force    Wipe data dirs (no prompt)"
	@echo ""
	@echo "  OVERRIDES:  L1_RPC=  L1_BEACON=  SEQ_IP=  DEPOSIT_AMOUNT=  FROM_ADDR=  PRIVKEY="
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — check-deps
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: check-deps
check-deps:
	@echo "=== [1] Checking prerequisites ==="
	@command -v docker  >/dev/null 2>&1 && echo "  ok docker  $$(docker --version | cut -d' ' -f3)" || { echo "  FAIL docker not found"; exit 1; }
	@command -v curl    >/dev/null 2>&1 && echo "  ok curl"    || { echo "  FAIL curl not found"; exit 1; }
	@command -v jq      >/dev/null 2>&1 && echo "  ok jq"      || { echo "  FAIL jq not found — apt install jq"; exit 1; }
	@command -v openssl >/dev/null 2>&1 && echo "  ok openssl" || { echo "  FAIL openssl not found"; exit 1; }
	@command -v cast    >/dev/null 2>&1 && echo "  ok cast (foundry) — bridge targets available" \
	    || echo "  WARN cast not found — bridge targets need foundry (curl -L https://foundry.paradigm.xyz | bash)"
	@echo "  === check-deps PASS ==="

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1b — pull images
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: pull-images
pull-images:
	@echo "=== Pulling OP Stack Docker images ==="
	docker pull $(OP_GETH_IMG)
	docker pull $(OP_NODE_IMG)
	@echo "  ok images ready"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — jwt
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: jwt
jwt: $(JWT_FILE)

$(JWT_FILE):
	@echo "=== [2] Generating JWT secret ==="
	openssl rand -hex 32 > $(JWT_FILE)
	chmod 600 $(JWT_FILE)
	@echo "  ok JWT written to $(JWT_FILE)"
	@echo "  NOTE: op-geth and op-node must share this file"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2b — fetch-genesis
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: fetch-genesis
fetch-genesis:
	@echo "=== Fetching genesis.json from sequencer $(SEQ_IP):8181 ==="
	@if curl -s --max-time 15 --connect-timeout 8 \
	    -o $(GENESIS) "http://$(SEQ_IP):8181/genesis.json" && [ -s $(GENESIS) ]; then \
	    echo "  ok genesis.json downloaded ($$(wc -c < $(GENESIS)) bytes)"; \
	else \
	    echo "  FAIL sequencer unreachable at $(SEQ_IP):8181"; \
	    echo "  Ask Nova/team for genesis.json out-of-band, then copy here: $(GENESIS)"; \
	    rm -f $(GENESIS); \
	    exit 1; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — init both data dirs
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: init
init: $(JWT_FILE)
	@echo "=== [3] Initializing op-geth data dirs ==="
	@test -f $(GENESIS) || { echo "  FAIL genesis.json missing — run: make fetch-genesis"; exit 1; }
	@test -f $(ROLLUP)  || { echo "  FAIL rollup.json missing in $(DIR)"; exit 1; }
	@mkdir -p $(SEQ_DATA) $(FOL_DATA)
	@echo "  -> sequencer data dir: $(SEQ_DATA)"
	docker run --rm -v $(DIR):/d -v $(SEQ_DATA):/data $(OP_GETH_IMG) \
	    --datadir /data init /d/genesis.json
	@echo "  -> follower data dir: $(FOL_DATA)"
	docker run --rm -v $(DIR):/d -v $(FOL_DATA):/data $(OP_GETH_IMG) \
	    --datadir /data init /d/genesis.json
	@echo "  ok both data dirs initialized"

.PHONY: genesis-check
genesis-check:
	@echo "=== Genesis hash verification ==="
	@EXPECTED=$$(jq -r '.genesis.l2.hash' $(ROLLUP)); \
	 echo "  rollup.json expects: $$EXPECTED"; \
	 ACTUAL=$$(curl -s --max-time 5 \
	     -X POST http://127.0.0.1:$(FOL_GETH_HTTP) \
	     -H 'Content-Type: application/json' \
	     -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["0x0",false]}' \
	     2>/dev/null | jq -r '.result.hash // empty'); \
	 if [ -n "$$ACTUAL" ]; then \
	     echo "  op-geth block 0:     $$ACTUAL"; \
	     [ "$$ACTUAL" = "$$EXPECTED" ] && echo "  MATCH ok" || echo "  MISMATCH -- reinit required"; \
	 else \
	     echo "  op-geth not reachable yet — start follower first, then run: make genesis-check"; \
	 fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Sequencer (op-geth + op-node in sequencer mode)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: seq-up
seq-up: $(JWT_FILE)
	@echo "=== [4] Starting SEQUENCER ==="
	@test -d $(SEQ_DATA) || { echo "  FAIL data dir missing — run: make init"; exit 1; }
	@echo "  -> op-geth (sequencer)"
	docker run -d --name op-seq-geth --network host \
	    -v $(DIR):/d -v $(SEQ_DATA):/data \
	    $(OP_GETH_IMG) \
	    --datadir /data \
	    --http --http.addr 0.0.0.0 --http.port $(SEQ_GETH_HTTP) \
	    --http.api eth,net,web3,debug,txpool \
	    --http.corsdomain '*' \
	    --ws --ws.addr 0.0.0.0 --ws.port 9645 \
	    --ws.api eth,net,web3,debug \
	    --authrpc.addr 127.0.0.1 --authrpc.port $(SEQ_GETH_AUTH) \
	    --authrpc.jwtsecret /d/jwt.txt \
	    --authrpc.vhosts '*' \
	    --syncmode full --gcmode archive \
	    --rollup.sequencerhttp http://127.0.0.1:$(SEQ_NODE_RPC) \
	    --rollup.disabletxpoolgossip \
	    --port $(SEQ_GETH_P2P) \
	    --networkid $(L2_CHAIN_ID)
	@sleep 3
	@echo "  -> op-node (sequencer mode)"
	docker run -d --name op-seq-node --network host \
	    -v $(DIR):/d \
	    $(OP_NODE_IMG) \
	    --l1=$(L1_RPC) \
	    --l1.beacon=$(L1_BEACON) \
	    --l1.trustrpc --l1.rpckind=standard \
	    --l2=http://127.0.0.1:$(SEQ_GETH_AUTH) \
	    --l2.jwt-secret=/d/jwt.txt \
	    --rollup.config=/d/rollup.json \
	    --rpc.addr=0.0.0.0 --rpc.port=$(SEQ_NODE_RPC) \
	    --p2p.listen.ip=0.0.0.0 \
	    --p2p.listen.tcp=$(SEQ_NODE_P2P) \
	    --p2p.listen.udp=$(SEQ_NODE_P2P) \
	    --sequencer.enabled \
	    --sequencer.l1-confs=4
	@echo "  ok Sequencer containers started"
	@echo "  Geth RPC: http://localhost:$(SEQ_GETH_HTTP)"
	@echo "  Node RPC: http://localhost:$(SEQ_NODE_RPC)"
	@echo "  (wait ~10s then: make status)"

.PHONY: seq-down
seq-down:
	docker stop op-seq-geth op-seq-node 2>/dev/null || true
	docker rm   op-seq-geth op-seq-node 2>/dev/null || true
	@echo "  ok sequencer stopped"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Follower node
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: follower-up
follower-up: $(JWT_FILE)
	@echo "=== [5] Starting FOLLOWER ==="
	@test -d $(FOL_DATA) || { echo "  FAIL data dir missing — run: make init"; exit 1; }
	@echo "  -> Probing sequencer P2P self (ENR)..."
	$(eval SEQ_ENR := $(shell curl -s --max-time 8 \
	    -X POST http://$(SEQ_IP):$(SEQ_RPC_PORT) \
	    -H 'Content-Type: application/json' \
	    -d '{"jsonrpc":"2.0","id":1,"method":"opp2p_self","params":[]}' \
	    2>/dev/null | jq -r '.result // empty' 2>/dev/null))
	@if [ -n "$(SEQ_ENR)" ]; then \
	    echo "  Sequencer ENR: $(SEQ_ENR)"; \
	else \
	    echo "  Sequencer ENR: not available -- will use --p2p.no-discovery"; \
	fi
	@echo "  -> op-geth (follower)"
	docker run -d --name op-fol-geth --network host \
	    -v $(DIR):/d -v $(FOL_DATA):/data \
	    $(OP_GETH_IMG) \
	    --datadir /data \
	    --http --http.addr 127.0.0.1 --http.port $(FOL_GETH_HTTP) \
	    --http.api eth,net,web3,debug \
	    --authrpc.addr 127.0.0.1 --authrpc.port $(FOL_GETH_AUTH) \
	    --authrpc.jwtsecret /d/jwt.txt \
	    --authrpc.vhosts '*' \
	    --syncmode full \
	    --maxpeers 25 \
	    --port $(FOL_GETH_P2P) \
	    --rollup.disabletxpoolgossip
	@sleep 3
	@echo "  -> op-node (follower + L1 derivation)"
	@if [ -n "$(SEQ_ENR)" ]; then \
	    docker run -d --name op-fol-node --network host \
	        -v $(DIR):/d \
	        $(OP_NODE_IMG) \
	        --l1=$(L1_RPC) \
	        --l1.beacon=$(L1_BEACON) \
	        --l1.trustrpc --l1.rpckind=standard \
	        --l2=http://127.0.0.1:$(FOL_GETH_AUTH) \
	        --l2.jwt-secret=/d/jwt.txt \
	        --rollup.config=/d/rollup.json \
	        --rpc.addr=127.0.0.1 --rpc.port=$(FOL_NODE_RPC) \
	        --p2p.listen.ip=0.0.0.0 \
	        --p2p.listen.tcp=$(FOL_NODE_P2P) \
	        --p2p.listen.udp=$(FOL_NODE_P2P) \
	        --p2p.static=$(SEQ_ENR); \
	else \
	    docker run -d --name op-fol-node --network host \
	        -v $(DIR):/d \
	        $(OP_NODE_IMG) \
	        --l1=$(L1_RPC) \
	        --l1.beacon=$(L1_BEACON) \
	        --l1.trustrpc --l1.rpckind=standard \
	        --l2=http://127.0.0.1:$(FOL_GETH_AUTH) \
	        --l2.jwt-secret=/d/jwt.txt \
	        --rollup.config=/d/rollup.json \
	        --rpc.addr=127.0.0.1 --rpc.port=$(FOL_NODE_RPC) \
	        --p2p.listen.ip=0.0.0.0 \
	        --p2p.listen.tcp=$(FOL_NODE_P2P) \
	        --p2p.listen.udp=$(FOL_NODE_P2P) \
	        --p2p.no-discovery; \
	fi
	@echo "  ok Follower containers started"
	@echo "  Geth RPC: http://127.0.0.1:$(FOL_GETH_HTTP)"
	@echo "  Node RPC: http://127.0.0.1:$(FOL_NODE_RPC)"
	@echo "  (wait ~30s then: make status)"

.PHONY: follower-down
follower-down:
	docker stop op-fol-geth op-fol-node 2>/dev/null || true
	docker rm   op-fol-geth op-fol-node 2>/dev/null || true
	@echo "  ok follower stopped"

# ─────────────────────────────────────────────────────────────────────────────
# STATUS
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: status
status:
	@echo "=== Sync Status ==="
	@echo "-- Sequencer op-node (:$(SEQ_NODE_RPC)) --"
	@curl -s --max-time 6 \
	    -X POST http://127.0.0.1:$(SEQ_NODE_RPC) \
	    -H 'Content-Type: application/json' \
	    -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' \
	    2>/dev/null | jq '{safe_l2:.result.safe_l2.number,unsafe_l2:.result.unsafe_l2.number,finalized_l2:.result.finalized_l2.number,current_l1:.result.current_l1.number}' \
	    2>/dev/null || echo "  (not reachable)"
	@echo "-- Follower op-node (:$(FOL_NODE_RPC)) --"
	@curl -s --max-time 6 \
	    -X POST http://127.0.0.1:$(FOL_NODE_RPC) \
	    -H 'Content-Type: application/json' \
	    -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' \
	    2>/dev/null | jq '{safe_l2:.result.safe_l2.number,unsafe_l2:.result.unsafe_l2.number,finalized_l2:.result.finalized_l2.number,current_l1:.result.current_l1.number}' \
	    2>/dev/null || echo "  (not reachable)"
	@echo "-- Nova live sequencer ($(SEQ_IP):$(SEQ_RPC_PORT)) --"
	@curl -s --max-time 6 \
	    -X POST http://$(SEQ_IP):$(SEQ_RPC_PORT) \
	    -H 'Content-Type: application/json' \
	    -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
	    2>/dev/null | jq '"head: " + (.result | tonumber | tostring)' \
	    2>/dev/null || echo "  (not reachable)"
	@echo "-- Docker containers --"
	@docker ps --filter name=op- --format '{{.Names}}\t{{.Status}}' 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# LOGS
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: logs
logs:
	docker logs -f --tail=80 op-fol-node 2>&1

.PHONY: logs-seq
logs-seq:
	docker logs -f --tail=80 op-seq-node 2>&1

# ─────────────────────────────────────────────────────────────────────────────
# BRIDGE — L1 -> L2 deposit
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: bridge-in
bridge-in:
	@test -n "$(FROM_ADDR)" || { echo "  FAIL: set FROM_ADDR=0x... on command line"; exit 1; }
	@test -n "$(PRIVKEY)"   || { echo "  FAIL: set PRIVKEY=0x... on command line (never commit)"; exit 1; }
	@command -v cast >/dev/null 2>&1 || { echo "  FAIL: cast (foundry) required"; exit 1; }
	@echo "=== Bridge-in: depositing $(DEPOSIT_AMOUNT) ETH L1 -> L2 ==="
	@echo "  From:    $(FROM_ADDR)"
	@echo "  Portal:  $(PORTAL_PROXY)  [Sepolia]"
	cast send \
	    --rpc-url $(L1_RPC) \
	    --private-key $(PRIVKEY) \
	    --value $(DEPOSIT_AMOUNT) \
	    $(PORTAL_PROXY) \
	    "depositTransaction(address,uint256,uint64,bool,bytes)" \
	    $(FROM_ADDR) 0 100000 false 0x
	@echo "  ok Deposit tx sent — L2 credit appears in ~2 blocks (~4s)"
	@echo "  Check: cast balance $(FROM_ADDR) --rpc-url http://127.0.0.1:$(FOL_GETH_HTTP)"

# ─────────────────────────────────────────────────────────────────────────────
# BRIDGE — L2 -> L1 withdrawal (3-step)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: bridge-out
bridge-out:
	@test -n "$(FROM_ADDR)" || { echo "  FAIL: set FROM_ADDR=0x..."; exit 1; }
	@test -n "$(PRIVKEY)"   || { echo "  FAIL: set PRIVKEY=0x..."; exit 1; }
	@command -v cast >/dev/null 2>&1 || { echo "  FAIL: cast required"; exit 1; }
	@echo "=== Bridge-out step 1/3: initiate L2 withdrawal ==="
	@echo "  TIMELINE: initiate -> wait L1 state root (~1h) -> prove -> 7d challenge -> finalize"
	cast send \
	    --rpc-url http://127.0.0.1:$(FOL_GETH_HTTP) \
	    --private-key $(PRIVKEY) \
	    --value $(DEPOSIT_AMOUNT) \
	    $(BRIDGE_PROXY) \
	    "bridgeETH(uint32,bytes)" \
	    200000 0x
	@echo "  ok L2 withdrawal initiated -- save the tx hash"
	@echo "  Next: make withdrawal-prove TX_HASH=<hash>"

.PHONY: withdrawal-prove
withdrawal-prove:
	@echo "=== Bridge-out step 2/3: prove withdrawal on L1 ==="
	@echo "  Requires: state root published to L1 (op-node outputs OutputProposed event)"
	@echo "  Use op-sdk or cast to call proveWithdrawalTransaction on $(PORTAL_PROXY)"
	@echo "  See: https://docs.optimism.io/builders/app-developers/bridging/standard-bridge"

.PHONY: withdrawal-finalize
withdrawal-finalize:
	@echo "=== Bridge-out step 3/3: finalize withdrawal ==="
	@echo "  7-day challenge period must have elapsed."
	@echo "  call finalizeWithdrawalTransaction on $(PORTAL_PROXY) with PRIVKEY"

# ─────────────────────────────────────────────────────────────────────────────
# STOP + CLEAN
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: stop
stop: seq-down follower-down
	@echo "  ok all containers stopped"

.PHONY: clean
clean: stop
	@echo "=== WARNING: wiping chain data dirs - CANNOT be undone ==="
	@read -p "  Type YES to confirm: " CONFIRM && [ "$$CONFIRM" = "YES" ] || exit 1
	rm -rf $(SEQ_DATA) $(FOL_DATA)
	@echo "  ok data dirs wiped — run: make init"

.PHONY: clean-force
clean-force: stop
	rm -rf $(SEQ_DATA) $(FOL_DATA)
	@echo "  ok data dirs wiped (no confirmation)"
