# ──────────────────────────────────────────────────────────────────────────
# Midterm #2 — OP Stack L2 ด้วย op-reth (reth family) + step-by-step deploy
# ChaiKlang Oracle (ชายกลาง) · AI, Rule 6
#
# op-reth (Rust EL) แทน op-geth = client diversity. op-node/L1/batcher คงเดิม.
# รันเป็น EL follower ของ ARRA chain (chainId 20260619, genesis 0x1c9445c6)
# พิสูจน์ด้วย byte-for-byte head-match กับ canonical sequencer.
#
# usage:  make deps && make pull && make configs && make verify-genesis \
#         && make init && make run-el && make run-cl && make status && make headmatch
# ──────────────────────────────────────────────────────────────────────────
SHELL        := /bin/bash
# --- params (override: make run-el RETH_HTTP=9999) ---
OPRETH_IMG   ?= ghcr.io/paradigmxyz/op-reth:latest
WORK         ?= $(HOME)/ck-opreth
OPNODE       ?= $(HOME)/op-stack/op-node
SEQ_RPC      ?= http://141.11.156.4:9545
SEQ_PEER     ?= /ip4/141.11.156.4/tcp/9227/p2p/16Uiu2HAkzt25EFAurBMAYJzwExEGKV4aUYkce7aRbEZwUDFmXoao
L1_RPC       ?= https://ethereum-sepolia-rpc.publicnode.com
CONFIG_SRC   ?= $(HOME)/ck-follower            # node ที่ sync แล้ว (canonical configs)
# ports (ck-namespaced กันชนเพื่อนบน shared box)
RETH_HTTP    ?= 28645
RETH_AUTH    ?= 28652
RETH_P2P     ?= 28403
NODE_RPC     ?= 28557
NODE_P2P     ?= 28237
CONTAINER    := ck-opreth
SCREEN_CL    := ck-reth-node

.PHONY: deps pull configs verify-genesis init run-el run-cl status headmatch clean all
all: deps pull configs verify-genesis init run-el run-cl status headmatch

deps:                  ## 1. ตรวจ podman + jq + curl + op-node
	@command -v podman >/dev/null || { echo "❌ podman ไม่มี (rootless podman จำเป็น)"; exit 1; }
	@command -v jq curl >/dev/null || { echo "❌ jq/curl ไม่มี"; exit 1; }
	@test -x "$(OPNODE)" || { echo "❌ op-node ไม่มีที่ $(OPNODE)"; exit 1; }
	@mkdir -p "$(WORK)/data"
	@echo "✅ deps ok"

pull:                  ## 2. ดึง op-reth image (ไม่ต้อง build rust)
	podman pull "$(OPRETH_IMG)"
	@podman run --rm "$(OPRETH_IMG)" --version | head -1

configs:               ## 3. ดึง genesis/rollup/jwt (canonical) จาก node ที่ sync แล้ว
	cp "$(CONFIG_SRC)/cfg-genesis.json" "$(WORK)/genesis.json"
	cp "$(CONFIG_SRC)/cfg-rollup.json"  "$(WORK)/rollup.json"
	cp "$(CONFIG_SRC)/cfg-jwt.txt"      "$(WORK)/jwt.txt"
	@echo "✅ configs copied"

verify-genesis:        ## 4. GUARD: reth-init == rollup l2 == live block0 (ไม่ตรง = abort)
	@RETH=$$(podman run --rm -v "$(WORK)":/cfg:Z -v "$(WORK)/data":/data:Z "$(OPRETH_IMG)" \
	   init --chain /cfg/genesis.json --datadir /data 2>&1 | grep -oE '0x[0-9a-f]{64}' | head -1); \
	 ROLLUP=$$(jq -r '.genesis.l2.hash' "$(WORK)/rollup.json"); \
	 LIVE=$$(curl -s -X POST $(SEQ_RPC) -H 'content-type:application/json' \
	   --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["0x0",false]}' | jq -r '.result.hash'); \
	 echo "reth-init: $$RETH"; echo "rollup l2: $$ROLLUP"; echo "live blk0: $$LIVE"; \
	 if [ "$$RETH" = "$$ROLLUP" ] && [ "$$RETH" = "$$LIVE" ]; then echo "✅ genesis 3-way MATCH"; \
	 else echo "❌ genesis MISMATCH — abort (อย่า sync เข้าผิดเชน)"; exit 1; fi

init: verify-genesis   ## 5. op-reth init (ผ่าน guard แล้ว)
	@echo "✅ initialized (datadir $(WORK)/data)"

run-el:                ## 6. start op-reth EL (authrpc + jwt + sequencer-http)
	-podman rm -f $(CONTAINER) 2>/dev/null
	podman run -d --name $(CONTAINER) --network host \
	  -v "$(WORK)":/cfg:Z -v "$(WORK)/data":/data:Z "$(OPRETH_IMG)" \
	  node --chain /cfg/genesis.json --datadir /data \
	  --http --http.addr 127.0.0.1 --http.port $(RETH_HTTP) --http.api eth,net,web3,debug \
	  --authrpc.addr 127.0.0.1 --authrpc.port $(RETH_AUTH) --authrpc.jwtsecret /cfg/jwt.txt \
	  --port $(RETH_P2P) --disable-discovery \
	  --rollup.sequencer-http $(SEQ_RPC) --rollup.disable-tx-pool-gossip
	@sleep 5; curl -s -X POST http://127.0.0.1:$(RETH_HTTP) -H 'content-type:application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'; echo "  ← op-reth EL up"

run-cl:                ## 7. start op-node CL (drive op-reth authrpc) — L1 derive + P2P
	-screen -ls | grep -oE '[0-9]+\.$(SCREEN_CL)' | cut -d. -f1 | xargs -r -I{} screen -S {} -X quit
	screen -dmS $(SCREEN_CL) bash -c "cd $(WORK) && $(OPNODE) \
	  --l1=$(L1_RPC) --l1.beacon.ignore=true --l1.trustrpc --l1.rpckind=standard \
	  --l2=http://127.0.0.1:$(RETH_AUTH) --l2.jwt-secret=$(WORK)/jwt.txt \
	  --rollup.config=$(WORK)/rollup.json \
	  --rpc.addr=127.0.0.1 --rpc.port=$(NODE_RPC) \
	  --p2p.listen.tcp=$(NODE_P2P) --p2p.listen.udp=$(NODE_P2P) --p2p.advertise.ip=141.11.156.4 \
	  --p2p.static=$(SEQ_PEER) \
	  --p2p.priv.path=$(WORK)/p2p.key --p2p.peerstore.path=$(WORK)/peerstore.db --p2p.discovery.path=$(WORK)/discv5.db \
	  --syncmode=consensus-layer --syncmode.req-resp \
	  --l1.rpc-max-batch-size=10 --l1.rpc-rate-limit=10 --l1.max-concurrency=10 \
	  --log.level=info 2>&1 | tee $(WORK)/opnode.log"
	@echo "✅ op-node driving op-reth (derive จาก L1 + P2P) — รอ ~2-4 นาที"

status:                ## 8. syncStatus + op-reth head
	@echo -n "op-reth head: "; curl -s -X POST http://127.0.0.1:$(RETH_HTTP) -H 'content-type:application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | jq -r '.result' | xargs -I{} python3 -c "print(int('{}',16))"
	@curl -s -X POST http://127.0.0.1:$(NODE_RPC) -H 'content-type:application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | jq '{unsafe:.result.unsafe_l2.number,safe:.result.safe_l2.number,finalized:.result.finalized_l2.number}'

headmatch:             ## 9. PROOF: op-reth block hash == canonical sequencer (byte-for-byte)
	@SAFE=$$(curl -s -X POST http://127.0.0.1:$(NODE_RPC) -H 'content-type:application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | jq -r '.result.safe_l2.number'); \
	 echo "comparing op-reth vs canonical at blocks 1, 50, $$((SAFE-2)):"; OK=0; T=0; \
	 for h in 1 50 $$((SAFE-2)); do hx=$$(printf '0x%x' $$h); T=$$((T+1)); \
	   M=$$(curl -s -X POST http://127.0.0.1:$(RETH_HTTP) -H 'content-type:application/json' --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByNumber\",\"params\":[\"$$hx\",false]}" | jq -r '.result.hash'); \
	   N=$$(curl -s -X POST $(SEQ_RPC) -H 'content-type:application/json' --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByNumber\",\"params\":[\"$$hx\",false]}" | jq -r '.result.hash'); \
	   if [ "$$M" = "$$N" ] && [ "$$M" != null ]; then echo "  block $$h: op-reth == sequencer ✅"; OK=$$((OK+1)); else echo "  block $$h: DIFFER ❌ reth=$$M seq=$$N"; fi; done; \
	 echo "RESULT: $$OK/$$T byte-for-byte identical"

clean:                 ## 10. หยุด EL+CL, เก็บ data aside (Rule 1: ไม่ลบ)
	-podman rm -f $(CONTAINER) 2>/dev/null
	-screen -ls | grep -oE '[0-9]+\.$(SCREEN_CL)' | cut -d. -f1 | xargs -r -I{} screen -S {} -X quit
	-mv "$(WORK)/data" "$(WORK)/data.bak.$$(date +%s)" 2>/dev/null
	@echo "✅ stopped; data เก็บ aside แล้ว"
