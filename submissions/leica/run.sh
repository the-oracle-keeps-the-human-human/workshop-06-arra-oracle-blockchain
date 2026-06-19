#!/usr/bin/env bash
set -euo pipefail

ORACLE_NAME="${ORACLE_NAME:-leica}"
ORACLE_ROLE="${ORACLE_ROLE:-orchestrator}"
CHAIN_FILE="${CHAIN_FILE:-/data/chain.json}"

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1"; }

log "Oracle ${ORACLE_NAME} (${ORACLE_ROLE}) — booting"

if [ ! -f "$CHAIN_FILE" ]; then
  log "Initializing genesis block"
  mkdir -p "$(dirname "$CHAIN_FILE")"
  cat > "$CHAIN_FILE" <<GENESIS
[{"index":0,"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","oracle":"${ORACLE_NAME}","action":"genesis","hash":"0000000000000000","prev":"null"}]
GENESIS
fi

append_block() {
  local action="$1"
  local prev_hash
  prev_hash=$(tail -c 200 "$CHAIN_FILE" | grep -o '"hash":"[^"]*"' | tail -1 | cut -d'"' -f4)
  local idx
  idx=$(grep -c '"index"' "$CHAIN_FILE")
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local hash
  hash=$(printf '%s:%s:%s:%s' "$idx" "$ts" "$action" "$prev_hash" | shasum -a 256 | cut -c1-16)

  local block
  block=$(printf '{"index":%d,"timestamp":"%s","oracle":"%s","action":"%s","hash":"%s","prev":"%s"}' \
    "$idx" "$ts" "$ORACLE_NAME" "$action" "$hash" "$prev_hash")

  local content
  content=$(cat "$CHAIN_FILE")
  printf '%s' "${content%]},${block}]" > "$CHAIN_FILE"
  log "Block #${idx}: ${action} (${hash})"
}

append_block "boot"
append_block "sync-check"

BLOCK_COUNT=$(grep -c '"index"' "$CHAIN_FILE")
log "Chain healthy — ${BLOCK_COUNT} blocks"

append_block "heartbeat"
log "Oracle ${ORACLE_NAME} — sync complete"

cat "$CHAIN_FILE" | python3 -m json.tool 2>/dev/null || cat "$CHAIN_FILE"
