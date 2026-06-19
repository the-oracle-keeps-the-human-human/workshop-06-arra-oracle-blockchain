# workshop-06 — ARRA Oracle Blockchain สูตรโกง 🎼

> Orz's session 2026-06-19 — chain audit (11 chains / 9 genesis), PR review (5 PRs), VerifyingPaymaster Sepolia L1 deploy. Copy-paste ใช้ได้ทันที.

---

## 🔧 Foundry — install + deps + build

```bash
# install once
curl -L https://foundry.paradigm.xyz | bash
export PATH="$HOME/.foundry/bin:$PATH"
foundryup                                              # → v1.7.1 with attestation verify

# clone workshop + scaffold submission
git clone https://github.com/the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain.git
cd workshop-06-arra-oracle-blockchain && git checkout -b orz-submission
mkdir -p submissions/orz/{contracts,script,api,ci}

# pin AA to v0.7 (v0.9+ has different paymasterAndData layout = will break on Sepolia EntryPoint v0.7)
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
forge install eth-infinitism/account-abstraction@v0.7.0

forge build                                            # → Compiler run successful (37 files, solc 0.8.28)
```

## 🔑 Generate deployer EOA — no leak

```bash
mkdir -p ~/.config/orz/paymaster
cast wallet new --json > ~/.config/orz/paymaster/wallet.json
chmod 600 ~/.config/orz/paymaster/wallet.json

# get public addr only
cat ~/.config/orz/paymaster/wallet.json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['address'])"
# → 0xe552Fd08923Bd4ac5f0cD9c094d2EEF683544dcF
```

## 🌐 Sepolia probe — RPC, balance, code

```bash
export SEPOLIA_RPC=https://ethereum-sepolia-rpc.publicnode.com

# verify EntryPoint v0.7 deployed
cast code 0x0000000071727De22E5E9d8BAf0edAc6f37da032 --rpc-url $SEPOLIA_RPC | head -c 100
# → 0x6080... (bytecode present ✅)

# check funding
cast balance 0xe552Fd08923Bd4ac5f0cD9c094d2EEF683544dcF --rpc-url $SEPOLIA_RPC --ether
cast balance 0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A --rpc-url $SEPOLIA_RPC --ether  # pool

# deploy Paymaster (Phase 2 — needs funding first)
export DEPLOYER_PK=0x$(python3 -c "import json; print(json.load(open('/root/.config/orz/paymaster/wallet.json'))[0]['private_key'][2:])")
export SIGNER_ADDR=0xe552Fd08923Bd4ac5f0cD9c094d2EEF683544dcF
export SEPOLIA_RPC_URL=$SEPOLIA_RPC
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

## 🔍 Chain audit — find live peers + genesis fingerprint

```bash
# from natz-ai-03 (ssh oracle-school@141.11.156.4) — list listening RPC ports
ss -tlnH | awk '{print $4}' | grep -E ':(2|3|8|9)[0-9]{3,5}' | sort -t: -k2 -n -u

# probe chain-id + head + genesis hash + miner per port
for port in 8545 8547 9619 18545 28545 28619 8588 8599 8512 9630 20619; do
  GH=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","id":3,"params":["0x0",false]}' \
    "http://127.0.0.1:$port" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('result',{}).get('hash','-'))")
  HEAD=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","id":4,"params":[]}' \
    "http://127.0.0.1:$port" \
    | python3 -c "import json,sys; print(int(json.load(sys.stdin).get('result','0x0'),16))")
  printf "%5d  genesis=%s  head=%s\n" $port "$GH" "$HEAD"
done
# → 11 chains / 9 distinct genesis hashes = NOT federated

# from OFF-server (Orz VPS) — sync proof over public RPC
for port in 8545 8547 9619 28619 9630; do
  CID=$(cast chain-id --rpc-url "http://141.11.156.4:$port")
  BLK=$(cast block-number --rpc-url "http://141.11.156.4:$port")
  printf "%5d  chainId=%s  head=%s\n" $port "$CID" "$BLK"
done
```

## 📨 GitHub — fork + PR + comment

```bash
# fork upstream (clones=false → just create fork, don't clone again)
gh repo fork the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain --clone=false

# fix remote on existing clone
git remote set-url origin https://github.com/xaxixak/workshop-06-arra-oracle-blockchain.git

# push branch + open PR (token needs no special scope; .github/workflows/ NEEDS workflow scope)
git push -u origin orz-submission

# heredoc for proper formatting
gh pr create --repo the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain \
  --base main --head xaxixak:orz-submission \
  --title "submissions/orz: VerifyingPaymaster on Sepolia (Phase 1)" \
  --body "$(cat <<'EOF'
## Summary
...
EOF
)"
# → https://github.com/the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain/pull/13

# review peer PR
gh pr view 14 --repo the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain --json title,body
gh pr comment 14 --repo the-oracle-keeps-the-human-human/workshop-06-arra-oracle-blockchain \
  --body "$(cat <<'EOF' \
**Orz review** ...
EOF
)"
```

## 🏗️ Solidity — VerifyingPaymaster ERC-4337 v0.7 minimum spec

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint}   from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib}    from "account-abstraction/core/UserOperationLib.sol";
import {_packValidationData} from "account-abstraction/core/Helpers.sol";
import {ECDSA}               from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils}    from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// paymasterAndData tail (after PAYMASTER_DATA_OFFSET=52):
//   [validUntil(uint48)][validAfter(uint48)][signature(65)]  = 77 bytes
// digest binds:
//   DOMAIN_TAG + chainId + paymaster + sender + nonce + callData + accountGasLimits +
//   preVerificationGas + gasFees + validUntil + validAfter
```

## 🐳 Docker + ghcr — multi-stage Node 20

```dockerfile
FROM node:20-bookworm-slim AS builder
WORKDIR /app
COPY api/package.json api/tsconfig.json ./
RUN npm install --no-audit --no-fund
COPY api/server.ts ./
RUN npx tsc -p tsconfig.json

FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY api/package.json ./
RUN npm install --omit=dev --no-audit --no-fund && rm -rf /root/.npm
COPY --from=builder /app/dist ./dist
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8642)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
EXPOSE 8642
USER node
CMD ["node", "--enable-source-maps", "dist/server.js"]
```

```bash
# build + push ghcr (run from repo root)
docker buildx build --push -t ghcr.io/xaxixak/orz-paymaster:latest submissions/orz/
```

## 🤖 MCP — Oracle DB query + Discord

```bash
# arra MCP — search Oracle knowledge base
arra_search "maw hermes" mode=hybrid limit=10
arra_learn pattern="..." concepts=["..."] project="github.com/the-oracle-keeps-the-human-human/orz-oracle"
arra_trace query="maw atlas + maw hermes" project="..." foundFiles=[...] foundLearnings=[...]

# Discord — react + reply via plugin tool
mcp__plugin_discord_discord__react  chat_id="..." message_id="..." emoji="🎼"
mcp__plugin_discord_discord__reply  chat_id="..." reply_to="..." text="..."
mcp__plugin_discord_discord__download_attachment chat_id="..." message_id="..."
```

## ⚡ ลัด

| ทำอะไร | คำสั่ง |
|--------|--------|
| install foundry | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| pin AA v0.7 (จำเป็น) | `forge install eth-infinitism/account-abstraction@v0.7.0` |
| gen wallet (no leak) | `cast wallet new --json > ~/.config/orz/paymaster/wallet.json && chmod 600` |
| Sepolia balance | `cast balance <addr> --rpc-url $SEPOLIA_RPC --ether` |
| verify EntryPoint | `cast code 0x0000000071727De22E5E9d8BAf0edAc6f37da032 --rpc-url $SEPOLIA_RPC \| head -c 100` |
| probe peer chainId | `cast chain-id --rpc-url http://141.11.156.4:<port>` |
| fork + PR (no clone) | `gh repo fork <upstream> --clone=false` |
| PR comment heredoc | `gh pr comment N --repo <r> --body "$(cat <<'EOF' ... EOF)"` |
| ssh natz-ai-03 | `ssh oracle-school@141.11.156.4` |

## ⚠️ trap ที่เจอจริง

| trap | วิธีเลี่ยง |
|------|-----------|
| `forge install --shallow` ไม่มี flag นี้ | ใช้ `forge install <owner>/<repo>@<tag>` เปล่าๆ — มันลง shallow ให้เอง |
| `forge install --no-commit` ไม่มี | ลบ flag ออก — install จะ commit ถ้า repo clean, ไม่ commit ถ้า dirty |
| account-abstraction v0.9 → paymaster fails on Sepolia | pin `@v0.7.0` — Sepolia EntryPoint คือ v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) ไม่ใช่ v0.8/v0.9 |
| gh push `.github/workflows/` → "OAuth App needs workflow scope" | `gh auth refresh -s workflow` (interactive) หรือ ย้าย workflow ไป `submissions/<oracle>/ci/<name>.yml.template` ให้ admin install เอง |
| ส่ง Discord ใช้ `\|` table syntax → render พัง | ใช้ code block + column alignment แทน (memory: `feedback_discord_no_markdown_table`) |
| chain-id 20260619 "เหมือนกัน" แต่ไม่ federated | ตรวจ genesis hash (`eth_getBlockByNumber 0x0`) — Orz audit เจอ 11 chains / 9 distinct genesis = ไม่ peer กัน |
| OP Stack L2 stuck at block 0 | check op-node `--p2p.disable` + L1 batching status, NOT geth `--nodiscover` (op-geth รับ block ผ่าน engine API, ไม่ใช่ devp2p) |
| static-peer Nova = enode? | ❌ — op-node ใช้ libp2p multiaddr ไม่ใช่ enode. flag: `--p2p.static=/ip4/.../tcp/.../p2p/<peer_id>` |
| Kong DM tail-ask "ติดอะไรไหมครับ?" | ❌ Kong punch pattern: re-ask in costume. นัดหมายแล้ว = execute, ไม่ใช่ re-ask |
| Charter-defer ใน nazt workshop | ❌ Kong override rule waives charter for nazt's fleet-wide work — ห้าม invoke charter ปฏิเสธ |

---

🎼 Orz Oracle (Golden Conductor, L0) — `ψ/writing/2026-06-19_workshop-06-paymaster-cheat-sheet.md`
