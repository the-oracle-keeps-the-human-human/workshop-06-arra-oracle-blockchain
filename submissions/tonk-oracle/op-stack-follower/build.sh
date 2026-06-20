#!/bin/bash
# WS-06 — build op-geth + op-node from source (no root, home-dir Go toolchain)
set -uo pipefail
log(){ echo "[$(date +%H:%M:%S)] $*"; }

ROOT=~/op-stack
GOROOT_DIR=~/go-toolchain/go
SRC=~/op-stack-build/src
mkdir -p "$ROOT" "$SRC" ~/go-toolchain
export GOPATH=~/go-toolchain/gopath
export GOCACHE=~/go-toolchain/gocache

# 1. Go toolchain
if [ ! -x "$GOROOT_DIR/bin/go" ]; then
  log "downloading go1.26.4..."
  curl -sL --max-time 180 https://go.dev/dl/go1.26.4.linux-amd64.tar.gz -o ~/go-toolchain/go.tgz || { log "go dl FAIL"; exit 1; }
  tar -C ~/go-toolchain -xzf ~/go-toolchain/go.tgz || { log "go extract FAIL"; exit 1; }
  log "go ready"
fi
export PATH="$GOROOT_DIR/bin:$PATH"
go version || { log "go not runnable"; exit 1; }

# 2. op-geth
if [ ! -x "$ROOT/op-geth-binary" ]; then
  log "cloning op-geth v1.101702.2..."
  rm -rf "$SRC/op-geth"
  git clone --depth 1 --branch v1.101702.2 https://github.com/ethereum-optimism/op-geth "$SRC/op-geth" 2>&1 | tail -2
  log "building op-geth (make geth)..."
  ( cd "$SRC/op-geth" && go run build/ci.go install -static ./cmd/geth ) >"$SRC/op-geth-build.log" 2>&1 \
    || ( cd "$SRC/op-geth" && make geth ) >>"$SRC/op-geth-build.log" 2>&1
  if [ -x "$SRC/op-geth/build/bin/geth" ]; then
    cp "$SRC/op-geth/build/bin/geth" "$ROOT/op-geth-binary"
    log "op-geth-binary ready: $("$ROOT/op-geth-binary" version 2>/dev/null | head -1)"
  else
    log "op-geth build FAIL — see $SRC/op-geth-build.log"; tail -15 "$SRC/op-geth-build.log"
  fi
fi

# 3. op-node
if [ ! -x "$ROOT/op-node" ]; then
  log "cloning optimism op-node/v1.19.0..."
  rm -rf "$SRC/optimism"
  git clone --depth 1 --branch op-node/v1.19.0 https://github.com/ethereum-optimism/optimism "$SRC/optimism" 2>&1 | tail -2
  log "building op-node..."
  VERSION=v1.19.0
  ( cd "$SRC/optimism/op-node" && go build -o "$ROOT/op-node" \
      -ldflags "-X main.GitCommit=workshop -X main.GitDate=20260620 -X main.Version=$VERSION" \
      ./cmd ) >"$SRC/op-node-build.log" 2>&1
  if [ -x "$ROOT/op-node" ]; then
    log "op-node ready: $("$ROOT/op-node" --version 2>/dev/null | head -1)"
  else
    log "op-node build FAIL — see $SRC/op-node-build.log"; tail -20 "$SRC/op-node-build.log"
  fi
fi

log "DONE. binaries:"; ls -la "$ROOT"
