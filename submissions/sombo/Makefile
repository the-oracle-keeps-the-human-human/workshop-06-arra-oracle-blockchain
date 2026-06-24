# OP Stack L2 Chain Deploy — Sombo's Makefile
# No.88 Sombo · Oracle Council · Workshop 06
# Based on real deployment experience (20 มิ.ย. 2026)
#
# Usage:
#   make help           เช็ค prerequisites
#   make setup          สร้าง directories + JWT
#   make init           init genesis
#   make start          start op-geth + op-node
#   make start-batcher  start batcher
#   make status         เช็ค sync status
#   make proof          byte-for-byte head match
#   make stop           stop all processes
#   make clean          ลบ data dir (destructive)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Config — แก้ตรงนี้
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHAIN_ID       ?= 20260619
L1_RPC         ?= https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON      ?= https://ethereum-sepolia-beacon-api.publicnode.com
L2_RPC         ?= http://localhost:9545
SEQUENCER_HOST ?= 141.11.156.4

# Paths
DATA_DIR       ?= ./data
JWT_FILE       ?= ./jwt.hex
GENESIS_FILE   ?= ./genesis.json
ROLLUP_FILE    ?= ./rollup.json

# Ports
GETH_AUTH_PORT ?= 8651
GETH_HTTP_PORT ?= 9545
NODE_HTTP_PORT ?= 8647
NODE_P2P_PORT  ?= 9227

# Keys (ต้อง export ก่อน make)
BATCHER_KEY    ?= $(BATCHER_PRIVATE_KEY)
P2P_SEQ_KEY    ?= $(P2P_SEQUENCER_KEY)

# PIDs
GETH_PID_FILE  := /tmp/op-geth.pid
NODE_PID_FILE  := /tmp/op-node.pid
BATCHER_PID_FILE := /tmp/op-batcher.pid

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Phony targets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
.PHONY: help prereqs setup init start start-geth start-node start-batcher \
        status proof verify-genesis balance stop clean logs watch

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 0: Help
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
help:
	@echo ""
	@echo "  OP Stack Deploy — No.88 Sombo · Workshop 06"
	@echo ""
	@echo "  Quick start:"
	@echo "    make prereqs          เช็ค dependencies"
	@echo "    make setup            สร้าง JWT + directories"
	@echo "    make fetch-genesis    ดึง genesis + rollup จาก sequencer"
	@echo "    make init             init op-geth data dir"
	@echo "    make start            start op-geth + op-node"
	@echo "    make start-batcher    start batcher (sequencer only)"
	@echo "    make status           sync status"
	@echo "    make proof            byte-for-byte head match"
	@echo ""
	@echo "  Ops:"
	@echo "    make stop             หยุดทุก process"
	@echo "    make logs             ดู logs (geth + node)"
	@echo "    make watch            watch sync status realtime"
	@echo "    make clean            ลบ data dir (destructive!)"
	@echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: Check prerequisites
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
prereqs:
	@echo "=== Checking prerequisites ==="
	@echo -n "op-geth:    "; op-geth version 2>/dev/null | head -1 || echo "NOT FOUND — build from https://github.com/ethereum-optimism/op-geth"
	@echo -n "op-node:    "; op-node --version 2>/dev/null | head -1 || echo "NOT FOUND — build from https://github.com/ethereum-optimism/optimism"
	@echo -n "op-batcher: "; op-batcher --version 2>/dev/null | head -1 || echo "NOT FOUND — build from optimism monorepo"
	@echo -n "cast:       "; cast --version 2>/dev/null | head -1 || echo "NOT FOUND — curl -L https://foundry.paradigm.xyz | bash"
	@echo ""
	@echo -n "BATCHER_PRIVATE_KEY: "; [ -n "$(BATCHER_KEY)" ] && echo "SET" || echo "NOT SET — export BATCHER_PRIVATE_KEY=0x..."
	@echo -n "P2P_SEQUENCER_KEY:   "; [ -n "$(P2P_SEQ_KEY)" ] && echo "SET" || echo "NOT SET (follower ok, sequencer needs this)"
	@echo ""
	@echo "⚠️  ถ้ารัน Linux binary บน Mac ARM64 = exec format error → ใช้ Docker"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: Setup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup:
	@echo "=== Setup ==="
	mkdir -p $(DATA_DIR)/geth
	@if [ ! -f $(JWT_FILE) ]; then \
		openssl rand -hex 32 > $(JWT_FILE); \
		echo "Created JWT: $(JWT_FILE)"; \
	else \
		echo "JWT exists: $(JWT_FILE)"; \
	fi
	@echo "Done."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: Fetch genesis from sequencer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
fetch-genesis:
	@echo "=== Fetching genesis from $(SEQUENCER_HOST):8181 ==="
	curl -s --max-time 30 http://$(SEQUENCER_HOST):8181/genesis.json -o $(GENESIS_FILE)
	curl -s --max-time 30 http://$(SEQUENCER_HOST):8181/rollup.json -o $(ROLLUP_FILE)
	@echo ""
	@echo "=== 3-way genesis check (ตาม Tonk's lesson) ==="
	@GENESIS_HASH=$$(cat $(GENESIS_FILE) | python3 -c "import json,sys,hashlib; d=sys.stdin.read(); print('(file hash not block hash — use init to get block hash)')" 2>/dev/null); \
	 echo "genesis.json: downloaded"
	@ROLLUP_GENESIS=$$(cat $(ROLLUP_FILE) | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('genesis',{}).get('l2',{}).get('hash','(not found)'))" 2>/dev/null); \
	 echo "rollup.json genesis.l2.hash: $$ROLLUP_GENESIS"
	@echo "live block 0: check after init + start: make verify-genesis"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: Genesis timestamp check
# ⚠️ CRITICAL: clock-wedge bug สาเหตุหลักที่ chain พัง
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
check-genesis-timestamp:
	@echo "=== Genesis timestamp check (prevent clock-wedge) ==="
	@if [ ! -f $(GENESIS_FILE) ]; then echo "genesis.json not found — run make fetch-genesis first"; exit 1; fi
	@GENESIS_TS=$$(cat $(GENESIS_FILE) | python3 -c "import json,sys; d=json.load(sys.stdin); ts=d.get('timestamp','0'); print(int(ts,16) if isinstance(ts,str) and ts.startswith('0x') else int(ts))" 2>/dev/null); \
	 L1_ORIGIN=$$(cat $(ROLLUP_FILE) 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('genesis',{}).get('l1',{}).get('number',0))" 2>/dev/null || echo "unknown"); \
	 echo "genesis timestamp: $$GENESIS_TS"; \
	 echo "L1 origin block:   $$L1_ORIGIN"; \
	 echo ""; \
	 echo "⚠️  ต้องตรวจสอบ: genesis timestamp >= timestamp ของ L1 block $$L1_ORIGIN"; \
	 echo "    cast block $$L1_ORIGIN --rpc-url $(L1_RPC) | grep timestamp"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: Init geth datadir
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
init: setup
	@echo "=== Init op-geth datadir ==="
	@if [ ! -f $(GENESIS_FILE) ]; then echo "genesis.json not found — run make fetch-genesis first"; exit 1; fi
	@if [ -d $(DATA_DIR)/geth/chaindata ]; then \
		echo "Data dir exists — skip init (run make clean first to reinit)"; \
	else \
		op-geth init --datadir $(DATA_DIR) $(GENESIS_FILE) && echo "Init complete"; \
	fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: Start op-geth (EL)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
start-geth:
	@echo "=== Starting op-geth ==="
	@if [ ! -f $(JWT_FILE) ]; then echo "jwt.hex not found — run make setup first"; exit 1; fi
	nohup op-geth \
		--datadir $(DATA_DIR) \
		--networkid $(CHAIN_ID) \
		--syncmode full \
		--gcmode archive \
		--http \
		--http.addr 0.0.0.0 \
		--http.port $(GETH_HTTP_PORT) \
		--http.api eth,net,web3,debug \
		--http.corsdomain "*" \
		--http.vhosts "*" \
		--ws \
		--ws.addr 0.0.0.0 \
		--ws.port 9546 \
		--ws.api eth,net,web3 \
		--authrpc.addr 127.0.0.1 \
		--authrpc.port $(GETH_AUTH_PORT) \
		--authrpc.jwtsecret $(JWT_FILE) \
		--authrpc.vhosts "*" \
		--rollup.disabletxpoolgossip \
		--maxpeers 0 \
		> /tmp/op-geth.log 2>&1 & \
	echo $$! > $(GETH_PID_FILE)
	@sleep 2
	@echo "op-geth PID: $$(cat $(GETH_PID_FILE))"
	@echo "Log: tail -f /tmp/op-geth.log"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 7: Start op-node (CL)
# ⚠️ --p2p.sequencer.key สำคัญมาก (Bug #4 ถ้าขาด)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
start-node:
	@echo "=== Starting op-node ==="
	@if [ ! -f $(ROLLUP_FILE) ]; then echo "rollup.json not found — run make fetch-genesis first"; exit 1; fi
	nohup op-node \
		--l1=$(L1_RPC) \
		--l1.beacon=$(L1_BEACON) \
		--l1.trustrpc \
		--l2=http://127.0.0.1:$(GETH_AUTH_PORT) \
		--l2.jwt-secret=$(JWT_FILE) \
		--rollup.config=$(ROLLUP_FILE) \
		--rpc.addr=0.0.0.0 \
		--rpc.port=$(NODE_HTTP_PORT) \
		--p2p.listen.ip=0.0.0.0 \
		--p2p.listen.tcp=$(NODE_P2P_PORT) \
		--p2p.listen.udp=$(NODE_P2P_PORT) \
		--p2p.static=/ip4/$(SEQUENCER_HOST)/tcp/9227/p2p/$(P2P_PEER_ID) \
		$(if $(P2P_SEQ_KEY),--p2p.sequencer.key=$(P2P_SEQ_KEY),) \
		$(if $(SEQUENCER),--sequencer.enabled --sequencer.l1-confs=0,) \
		> /tmp/op-node.log 2>&1 & \
	echo $$! > $(NODE_PID_FILE)
	@sleep 2
	@echo "op-node PID: $$(cat $(NODE_PID_FILE))"
	@echo "Log: tail -f /tmp/op-node.log"

start: start-geth start-node
	@echo "=== Both started ==="
	@echo "Check: make status"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 8: Start batcher (sequencer only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
start-batcher:
	@echo "=== Starting op-batcher ==="
	@if [ -z "$(BATCHER_KEY)" ]; then echo "BATCHER_PRIVATE_KEY not set — export it first"; exit 1; fi
	@BATCHER_ADDR=$$(cast wallet address $(BATCHER_KEY) 2>/dev/null); \
	 BALANCE=$$(cast balance $$BATCHER_ADDR --rpc-url $(L1_RPC) --ether 2>/dev/null); \
	 echo "Batcher address: $$BATCHER_ADDR"; \
	 echo "Batcher balance: $$BALANCE ETH"; \
	 if [ "$$(echo "$$BALANCE < 0.1" | bc -l 2>/dev/null)" = "1" ]; then \
	   echo "⚠️  Low balance — batcher ส่ง batch ไม่ได้"; \
	 fi
	nohup op-batcher \
		--l1-eth-rpc=$(L1_RPC) \
		--l2-eth-rpc=http://127.0.0.1:$(GETH_HTTP_PORT) \
		--rollup-rpc=http://127.0.0.1:$(NODE_HTTP_PORT) \
		--private-key=$(BATCHER_KEY) \
		--num-confirmations=1 \
		--max-channel-duration=1 \
		> /tmp/op-batcher.log 2>&1 & \
	echo $$! > $(BATCHER_PID_FILE)
	@sleep 2
	@echo "op-batcher PID: $$(cat $(BATCHER_PID_FILE))"
	@echo "Log: tail -f /tmp/op-batcher.log"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 9: Check status
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
status:
	@echo "=== Sync Status ==="
	@curl -s -XPOST $(L2_RPC) \
		-H 'content-type:application/json' \
		--data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' \
		| python3 -c "import json,sys; d=json.load(sys.stdin)['result']; \
		  print('unsafe_l2:    ', d['unsafe_l2']['number']); \
		  print('safe_l2:      ', d['safe_l2']['number']); \
		  print('finalized_l2: ', d['finalized_l2']['number']); \
		  print('current_l1:   ', d['current_l1']['number']); \
		" 2>/dev/null || echo "(L2 RPC not reachable — check if op-geth is running)"
	@echo ""
	@echo "=== Block Number ==="
	@cast block-number --rpc-url $(L2_RPC) 2>/dev/null || echo "(cast not available or L2 not reachable)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 10: Proof — byte-for-byte head match
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
proof:
	@echo "=== Byte-for-byte head match proof ==="
	@SAFE_NUM=$$(curl -s -XPOST $(L2_RPC) -H 'content-type:application/json' \
		--data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' \
		| python3 -c "import json,sys; print(json.load(sys.stdin)['result']['safe_l2']['number'])" 2>/dev/null); \
	 echo "safe_l2 = $$SAFE_NUM"; \
	 LOCAL_HASH=$$(cast block $$SAFE_NUM --rpc-url $(L2_RPC) --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])"); \
	 SEQ_HASH=$$(cast block $$SAFE_NUM --rpc-url http://$(SEQUENCER_HOST):9545 --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])"); \
	 echo "local hash:     $$LOCAL_HASH"; \
	 echo "sequencer hash: $$SEQ_HASH"; \
	 if [ "$$LOCAL_HASH" = "$$SEQ_HASH" ]; then \
	   echo "✅ MATCH — byte-for-byte L1 derivation proof"; \
	 else \
	   echo "❌ MISMATCH — genesis หรือ rollup config ไม่ตรงกับ sequencer"; \
	 fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Genesis verify (3-way check)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verify-genesis:
	@echo "=== 3-way genesis hash verify (Tonk method) ==="
	@ROLLUP_HASH=$$(cat $(ROLLUP_FILE) | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('genesis',{}).get('l2',{}).get('hash','not-found'))" 2>/dev/null); \
	 LIVE_HASH=$$(cast block 0 --rpc-url $(L2_RPC) --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])"); \
	 SEQ_HASH=$$(cast block 0 --rpc-url http://$(SEQUENCER_HOST):9545 --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])"); \
	 echo "rollup.json genesis hash: $$ROLLUP_HASH"; \
	 echo "local block 0 hash:       $$LIVE_HASH"; \
	 echo "sequencer block 0 hash:   $$SEQ_HASH"; \
	 if [ "$$ROLLUP_HASH" = "$$LIVE_HASH" ] && [ "$$LIVE_HASH" = "$$SEQ_HASH" ]; then \
	   echo "✅ All 3 match — genesis consistent"; \
	 else \
	   echo "❌ Mismatch — re-fetch genesis or re-init"; \
	 fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Balance check
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
balance:
	@echo "=== Batcher balance on L1 ==="
	@if [ -n "$(BATCHER_KEY)" ]; then \
	  ADDR=$$(cast wallet address $(BATCHER_KEY) 2>/dev/null); \
	  cast balance $$ADDR --rpc-url $(L1_RPC) --ether 2>/dev/null | xargs -I{} echo "  $$ADDR: {} ETH"; \
	else \
	  echo "BATCHER_PRIVATE_KEY not set"; \
	fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Stop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
stop:
	@echo "=== Stopping processes ==="
	@[ -f $(GETH_PID_FILE) ] && kill $$(cat $(GETH_PID_FILE)) 2>/dev/null && echo "op-geth stopped" || true
	@[ -f $(NODE_PID_FILE) ] && kill $$(cat $(NODE_PID_FILE)) 2>/dev/null && echo "op-node stopped" || true
	@[ -f $(BATCHER_PID_FILE) ] && kill $$(cat $(BATCHER_PID_FILE)) 2>/dev/null && echo "op-batcher stopped" || true
	@rm -f $(GETH_PID_FILE) $(NODE_PID_FILE) $(BATCHER_PID_FILE)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logs
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
logs:
	@tail -f /tmp/op-geth.log /tmp/op-node.log 2>/dev/null || echo "No logs found — start processes first"

# Watch sync status (ทุก 5s)
watch:
	@while true; do clear; make status 2>/dev/null; sleep 5; done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Clean (destructive)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
clean: stop
	@echo "⚠️  Removing data dir: $(DATA_DIR)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] && rm -rf $(DATA_DIR) && echo "Cleaned" || echo "Cancelled"
