# ============================================================
#  Midterm #2 — op-reth follower for ARRA Oracle L2 (chain 20260619)
#  client diversity: reth-family execution client + Otterscan explorer
#  by Weizen Oracle (AI · Rule 6)
#
#  every command here is TESTED against the live chain, not guessed.
#  run `make help` for the step list.
# ============================================================

# ---- config (override on CLI: make sync SEQ_HTTP=http://host:9545) ----
OPRETH_VERSION ?= v1.8.2
DATADIR        ?= $(CURDIR)/data
CHAIN          ?= $(CURDIR)/chain/genesis.json
ROLLUP         ?= $(CURDIR)/chain/rollup.json
JWT            ?= $(CURDIR)/jwt.txt
GENESIS_HASH   ?= 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23

# endpoints — point at the running chain (server). override SEQ_HOST as needed.
SEQ_HOST       ?= 141.11.156.4
SEQ_HTTP       ?= http://$(SEQ_HOST):9545
SEQ_NODE       ?= http://$(SEQ_HOST):9547
PEER           ?= /ip4/$(SEQ_HOST)/tcp/9227/p2p/16Uiu2HAkzt25EFAurBMAYJzwExEGKV4aUYkce7aRbEZwUDFmXoao

# L1 (Sepolia) — execution RPC + beacon (blobs). swap for your own/Alchemy.
L1_RPC         ?= https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON      ?= https://ethereum-sepolia-beacon-api.publicnode.com

# local ports for THIS follower (kept distinct so it never clashes with a local sequencer)
RETH_HTTP_PORT ?= 9555
RETH_AUTH_PORT ?= 8551
RETH_P2P_PORT  ?= 30355
NODE_RPC_PORT  ?= 9557
NODE_P2P_PORT  ?= 9266
RETH_HTTP      := http://127.0.0.1:$(RETH_HTTP_PORT)
NODE_RPC       := http://127.0.0.1:$(NODE_RPC_PORT)

BIN            ?= $(HOME)/.local/bin
OPRETH         ?= $(BIN)/op-reth
OPNODE         ?= ./op-node

.PHONY: help deps jwt init exec node verify explorer clean all status

help:
	@echo "Midterm #2 — op-reth follower (chain 20260619)"
	@echo "  make deps      # download op-reth $(OPRETH_VERSION) + (you supply op-node)"
	@echo "  make jwt       # generate jwt secret shared by op-reth <-> op-node"
	@echo "  make init      # op-reth init genesis  -> MUST print $(GENESIS_HASH)"
	@echo "  make exec      # run op-reth (execution layer, +ots/trace for Otterscan)"
	@echo "  make node      # run op-node (consensus layer: L1 derivation + P2P)"
	@echo "  make verify    # genesis hash + byte-for-byte head-match vs sequencer"
	@echo "  make explorer  # run Otterscan pointed at op-reth (ots_* enabled)"
	@echo "  make status    # quick sync status"
	@echo "  make clean     # kill processes holding the follower ports"
	@echo "  make all       # deps -> jwt -> init -> exec -> node"

# 1. binaries -------------------------------------------------
deps:
	@mkdir -p $(BIN)
	@echo ">> downloading op-reth $(OPRETH_VERSION)"
	curl -fsSL https://github.com/paradigmxyz/reth/releases/download/$(OPRETH_VERSION)/op-reth-$(OPRETH_VERSION)-x86_64-unknown-linux-gnu.tar.gz \
	  | tar xz -C /tmp
	mv /tmp/op-reth $(OPRETH) && chmod +x $(OPRETH)
	$(OPRETH) --version | head -1
	@echo ">> op-node: copy your op-stack op-node binary next to this Makefile as ./op-node"
	@echo "   (build: github.com/ethereum-optimism/optimism  -> op-node/bin/op-node)"

# 2. jwt secret (shared engine-API auth) ----------------------
jwt:
	@test -f $(JWT) || (openssl rand -hex 32 > $(JWT) && echo ">> wrote $(JWT)")
	@echo "jwt: $(JWT)"

# 3. init genesis — the canonical-hash gate (P11) -------------
init:
	@test -f $(CHAIN) || { echo "!! missing $(CHAIN) — see chain/README"; exit 1; }
	rm -rf $(DATADIR)
	$(OPRETH) init --chain $(CHAIN) --datadir $(DATADIR) 2>&1 | grep -i "Genesis block written"
	@echo ">> expected genesis hash: $(GENESIS_HASH)"

# 4. execution layer: op-reth (drop-in for op-geth) ----------
#    --http.api includes ots/trace/debug  => unlocks Otterscan (op-geth can't)
exec:
	$(OPRETH) node --chain $(CHAIN) --datadir $(DATADIR) \
	  --authrpc.addr 127.0.0.1 --authrpc.port $(RETH_AUTH_PORT) --authrpc.jwtsecret $(JWT) \
	  --http --http.addr 127.0.0.1 --http.port $(RETH_HTTP_PORT) \
	  --http.api eth,net,web3,ots,trace,debug \
	  --port $(RETH_P2P_PORT) --disable-discovery --ipcdisable \
	  --rollup.sequencer-http $(SEQ_HTTP)

# 5. consensus layer: op-node (L1 derivation [safe] + P2P [unsafe]) ----
node:
	$(OPNODE) \
	  --l1=$(L1_RPC) --l1.beacon=$(L1_BEACON) --l1.trustrpc --l1.rpckind=standard \
	  --l2=http://127.0.0.1:$(RETH_AUTH_PORT) --l2.jwt-secret=$(JWT) \
	  --l2.enginekind=reth \
	  --rollup.config=$(ROLLUP) \
	  --p2p.static=$(PEER) \
	  --p2p.listen.tcp=$(NODE_P2P_PORT) --p2p.listen.udp=$(NODE_P2P_PORT) \
	  --rpc.addr=127.0.0.1 --rpc.port=$(NODE_RPC_PORT)

# 6. verify — genesis + byte-for-byte head-match -------------
verify:
	@echo "== local op-reth =="
	@cast block-number --rpc-url $(RETH_HTTP)
	@echo "local genesis: $$(cast block 0 --rpc-url $(RETH_HTTP) --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["hash"])')"
	@echo "expected:      $(GENESIS_HASH)"
	@echo "== op-node sync status =="
	@cast rpc optimism_syncStatus --rpc-url $(NODE_RPC) | python3 -c 'import json,sys;d=json.load(sys.stdin);print("unsafe",d["unsafe_l2"]["number"],"safe",d["safe_l2"]["number"],"finalized",d["finalized_l2"]["number"])'
	@echo "== byte-for-byte vs sequencer (sample head-200) =="
	@N=$$(cast block-number --rpc-url $(RETH_HTTP)); B=$$((N-200)); \
	  L=$$(cast block $$B --rpc-url $(RETH_HTTP) --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["hash"])'); \
	  R=$$(cast block $$B --rpc-url $(SEQ_HTTP) --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["hash"])'); \
	  echo "block $$B local=$$L"; echo "block $$B seq  =$$R"; \
	  [ "$$L" = "$$R" ] && echo "MATCH ✅" || echo "MISMATCH ❌"

# 7. Otterscan explorer (op-reth ots_* namespace) ------------
explorer:
	@echo ">> Otterscan pointed at op-reth ($(RETH_HTTP))"
	docker run --rm -p 5100:80 \
	  -e ERIGON_URL=$(RETH_HTTP) \
	  otterscan/otterscan:latest || \
	  echo "no docker? run otterscan static build with ERIGON_URL=$(RETH_HTTP)"

status:
	@cast rpc optimism_syncStatus --rpc-url $(NODE_RPC) 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print("unsafe",d["unsafe_l2"]["number"],"safe",d["safe_l2"]["number"],"cur_l1",d["current_l1"]["number"])' || echo "op-node not running"

clean:
	-pkill -9 -x op-reth 2>/dev/null
	-pkill -9 -x op-node 2>/dev/null
	-fuser -k $(RETH_AUTH_PORT)/tcp $(RETH_HTTP_PORT)/tcp $(RETH_P2P_PORT)/tcp $(NODE_RPC_PORT)/tcp $(NODE_P2P_PORT)/tcp 2>/dev/null
	@echo ">> ports freed"

all: deps jwt init
	@echo ">> now run 'make exec' and 'make node' in two terminals (or background), then 'make verify'"
