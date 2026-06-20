# Atom Oracle — Midterm 2 OP Stack deploy Makefile
# No secrets are committed. Override every value with env vars or .env.local.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

-include .env.local

CHAIN_ID ?= 20260619
WORKDIR ?= $(CURDIR)/run
CONFIG_BASE ?= http://141.11.156.4:8181
L1_RPC ?= https://ethereum-sepolia-rpc.publicnode.com
L1_BEACON ?= https://ethereum-sepolia-beacon-api.publicnode.com
L2_RPC_PORT ?= 9545
L2_AUTH_PORT ?= 9551
OP_NODE_RPC_PORT ?= 9547
OP_NODE_P2P_PORT ?= 9222
EXEC_CLIENT ?= op-geth
OP_RETH ?= op-reth
OP_RETH_CHAIN ?=
OP_GETH ?= geth
OP_NODE ?= op-node
ROLLUP_JSON ?= $(WORKDIR)/rollup.json
GENESIS_JSON ?= $(WORKDIR)/genesis.json
JWT_FILE ?= $(WORKDIR)/jwt.hex
SEQUENCER_RPC ?= http://127.0.0.1:$(L2_RPC_PORT)
SEQUENCER_MULTIADDR ?=
EXPECTED_L2_GENESIS ?= 0x1c9445c6cac6880fae00b45dedfc8bf43ce5fd39ec8eb9053b02e2e89a09ff23
LOGDIR ?= $(WORKDIR)/logs

.PHONY: help preflight dirs fetch-config jwt init-exec run-exec run-op-reth run-op-geth run-node verify clean print-env

help: ## Show step-by-step deploy targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "%-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

print-env: ## Print resolved env without secrets
	@printf 'CHAIN_ID=%s\nWORKDIR=%s\nEXEC_CLIENT=%s\nL1_RPC=%s\nL1_BEACON=%s\n' '$(CHAIN_ID)' '$(WORKDIR)' '$(EXEC_CLIENT)' '$(L1_RPC)' '$(L1_BEACON)'
	@printf 'OP_RETH_CHAIN=%s\n' '$(OP_RETH_CHAIN)'
	@printf 'ROLLUP_JSON=%s\nGENESIS_JSON=%s\nJWT_FILE=%s\nEXPECTED_L2_GENESIS=%s\n' '$(ROLLUP_JSON)' '$(GENESIS_JSON)' '$(JWT_FILE)' '$(EXPECTED_L2_GENESIS)'

preflight: ## Check required local tools
	@command -v curl >/dev/null
	@command -v jq >/dev/null
	@command -v $(OP_NODE) >/dev/null || echo 'warn: op-node not found; set OP_NODE=/path/to/op-node'
	@if [ '$(EXEC_CLIENT)' = 'op-reth' ]; then command -v $(OP_RETH) >/dev/null || echo 'warn: op-reth not found; set OP_RETH=/path/to/op-reth'; fi
	@if [ '$(EXEC_CLIENT)' = 'op-geth' ]; then command -v $(OP_GETH) >/dev/null || echo 'warn: geth not found; set OP_GETH=/path/to/geth'; fi

dirs: ## Create local runtime directories
	@mkdir -p '$(WORKDIR)' '$(LOGDIR)' '$(WORKDIR)/execution'

fetch-config: dirs ## Download genesis/rollup config from CONFIG_BASE
	@curl -fsSL '$(CONFIG_BASE)/genesis.json' -o '$(GENESIS_JSON)'
	@curl -fsSL '$(CONFIG_BASE)/rollup.json' -o '$(ROLLUP_JSON)'
	@actual=$$(jq -r '.genesis.l2.hash // empty' '$(ROLLUP_JSON)'); \
		echo "rollup genesis: $$actual"; \
		if [ -n '$(EXPECTED_L2_GENESIS)' ] && [ "$$actual" != '$(EXPECTED_L2_GENESIS)' ]; then \
			echo "ERROR: rollup genesis mismatch; refusing stale config"; exit 1; \
		fi

jwt: dirs ## Generate Engine API JWT if missing
	@test -s '$(JWT_FILE)' || openssl rand -hex 32 > '$(JWT_FILE)'
	@chmod 600 '$(JWT_FILE)'

init-exec: dirs fetch-config ## Initialize legacy op-geth datadir from genesis.json
	@$(OP_GETH) init --datadir '$(WORKDIR)/execution' '$(GENESIS_JSON)'

run-exec: jwt ## Run selected execution client: EXEC_CLIENT=op-reth|op-geth
	@if [ '$(EXEC_CLIENT)' = 'op-reth' ]; then $(MAKE) run-op-reth; else $(MAKE) run-op-geth; fi

run-op-reth: jwt ## Run op-reth execution client (recommended new path)
	@mkdir -p '$(LOGDIR)'
	@test -n '$(OP_RETH_CHAIN)' || (echo 'OP_RETH_CHAIN required: path/name for a reth-compatible OP chain spec' && exit 1)
	@$(OP_RETH) node \
		--chain '$(OP_RETH_CHAIN)' \
		--datadir '$(WORKDIR)/execution' \
		--http --http.addr 0.0.0.0 --http.port '$(L2_RPC_PORT)' \
		--authrpc.addr 127.0.0.1 --authrpc.port '$(L2_AUTH_PORT)' --authrpc.jwtsecret '$(JWT_FILE)' \
		2>&1 | tee '$(LOGDIR)/op-reth.log'

run-op-geth: jwt init-exec ## Run legacy op-geth execution client
	@mkdir -p '$(LOGDIR)'
	@$(OP_GETH) \
		--datadir '$(WORKDIR)/execution' \
		--http --http.addr 0.0.0.0 --http.port '$(L2_RPC_PORT)' --http.api eth,net,web3,debug \
		--authrpc.addr 127.0.0.1 --authrpc.port '$(L2_AUTH_PORT)' --authrpc.jwtsecret '$(JWT_FILE)' \
		--rollup.disabletxpoolgossip \
		2>&1 | tee '$(LOGDIR)/op-geth.log'

run-node: jwt fetch-config ## Run op-node consensus/rollup node
	@test -n '$(L1_RPC)' || (echo 'L1_RPC required' && exit 1)
	@test -n '$(L1_BEACON)' || (echo 'L1_BEACON required' && exit 1)
	@mkdir -p '$(LOGDIR)'
	@$(OP_NODE) \
		--l1='$(L1_RPC)' \
		--l1.beacon='$(L1_BEACON)' \
		--l2='http://127.0.0.1:$(L2_AUTH_PORT)' \
		--l2.jwt-secret='$(JWT_FILE)' \
		--rollup.config='$(ROLLUP_JSON)' \
		--rpc.addr=0.0.0.0 --rpc.port='$(OP_NODE_RPC_PORT)' \
		--p2p.listen.tcp='$(OP_NODE_P2P_PORT)' --p2p.listen.udp='$(OP_NODE_P2P_PORT)' \
		$(if $(SEQUENCER_MULTIADDR),--p2p.static='$(SEQUENCER_MULTIADDR)',) \
		2>&1 | tee '$(LOGDIR)/op-node.log'

verify: ## Verify L2 RPC and op-node sync status
	@curl -fsS 'http://127.0.0.1:$(L2_RPC_PORT)' -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | jq .
	@curl -fsS 'http://127.0.0.1:$(OP_NODE_RPC_PORT)' -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}' | jq '.result | {unsafe_l2, safe_l2, finalized_l2}'

clean: ## Remove local runtime data only
	@rm -rf '$(WORKDIR)'
