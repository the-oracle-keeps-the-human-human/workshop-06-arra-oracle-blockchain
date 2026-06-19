# Orz Oracle Submission — VerifyingPaymaster on Sepolia 🎼

> "วาทยกรไม่ตีกลอง — แต่ทำให้ทุกระบบขับเคลื่อนพร้อมกัน" — Orz Oracle (the Golden Conductor)

## TL;DR

| Field | Value |
|---|---|
| **Oracle** | Orz (Golden Conductor, L0) |
| **Stack** | ERC-4337 v0.7 on **Sepolia L1** (chainId `11155111`) |
| **Paymaster type** | **VerifyingPaymaster** (off-chain signer authorises userOps) |
| **EntryPoint** | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` (canonical v0.7) |
| **API** | Node.js signer service → ghcr.io image |
| **Repo** | this folder under `submissions/orz/` |
| **Mode** | submission stub + Foundry skeleton + Dockerfile + ghcr CI (Phase 1) → real Sepolia deploy + OtterScan link (Phase 2) |

## Why VerifyingPaymaster (and not TokenPaymaster) for the first ship

Three reasons in order of weight:

1. **Off-chain signing = policy in code, not in token economics.** Orz is the *Golden Conductor* — coordinating who gets gas-sponsored is the job, not minting a token to gate it. A VerifyingPaymaster keeps policy as a server (`/sponsor`) rather than as a deployed ERC-20. Easier to evolve, easier to revoke.
2. **TokenPaymaster needs a token + oracle + AMM liquidity.** That's three more failure modes before the first userOp lands. Phase-3 follow-up if there's a real demand for gas-token UX.
3. **The exercise is "deploy to L1 Sepolia for real" (nazt 07:34 UTC 2026-06-19).** VerifyingPaymaster gets us there with one contract + one signer + EntryPoint stake. Real money flow, minimal surface.

## Architecture

```
┌──────────────┐    1. userOp (no gas)    ┌─────────────────────┐
│ user / dApp  │ ───────────────────────▶ │  Orz Paymaster API  │ (this folder /api)
└──────────────┘                          │  POST /sponsor      │
       │                                  │  - validate caller  │
       │  3. signed paymasterData         │  - sign userOpHash  │
       │ ◀────────────────────────────── │   (EOA: SIGNER_PK)  │
       │                                  └─────────────────────┘
       │                                              ▲ off-chain
       │  4. submit to bundler                        │
       ▼                                              │
┌──────────────────────────┐                          │
│  ERC-4337 EntryPoint v0.7│  5. calls paymaster.validatePaymasterUserOp
│  0x...71727De22E5E9d8B   │  ─────────────────────────────────────────▶
└──────────────────────────┘                                            │
       │                                                                ▼
       │  6. handleOps → execute calldata        ┌───────────────────────────────┐
       ▼                                          │ OrzVerifyingPaymaster.sol     │
   target contract                                │ - SIGNER (EOA pubkey)         │
                                                  │ - deposit ETH at EntryPoint   │
                                                  │ - validate ECDSA on userOpHash│
                                                  └───────────────────────────────┘
```

Three moving parts:

| Component | Where | What it does |
|---|---|---|
| `OrzVerifyingPaymaster.sol` | `contracts/` | On-chain ERC-4337 paymaster; checks that `paymasterData` carries a fresh ECDSA signature from `SIGNER` over the userOpHash + validity window. Holds deposit at EntryPoint. |
| `api/server.ts` | `api/` | Node.js HTTP service (port `8642` matching the fleet's Hermes-gateway convention). Exposes `POST /sponsor` — validates the caller via allowlist, signs `(userOpHash, validUntil, validAfter)` with `SIGNER_PK`, returns the encoded `paymasterAndData` blob. |
| `Deploy.s.sol` | `script/` | Foundry deploy script — `forge script` to Sepolia using `SIGNER_PK` env var, deposits 0.1 ETH at EntryPoint as initial stake. |

## What's in this submission (Phase 1)

```
submissions/orz/
├── README.md                       (this file — design + deploy plan)
├── foundry.toml                    (Foundry config)
├── contracts/
│   └── OrzVerifyingPaymaster.sol   (ERC-4337 v0.7 BasePaymaster + ECDSA)
├── script/
│   └── Deploy.s.sol                (forge script for Sepolia)
├── api/
│   ├── server.ts                   (signer API on :8642)
│   ├── package.json
│   └── tsconfig.json
├── Dockerfile                      (multi-stage: Node 20 slim, healthcheck)
├── docker-compose.yml              (paymaster-api on :8642)
├── .env.example                    (deploy + runtime env keys; never commit .env)
├── .gitignore                      (Foundry out/, node_modules/, secrets)
└── ci/
    └── orz-ghcr.yml.template       (workflow — copy to .github/workflows/orz-ghcr.yml
                                     at repo root to activate; ChaiKlang or root-tier
                                     to install, requires `workflow` OAuth scope)
```

## Deploy plan (Phase 2 — real Sepolia)

1. Generate Orz signer EOA (deterministic, password-derived) → `SIGNER_PK` in `pass orz/paymaster-signer-pk`.
2. Request 0.25 Sepolia ETH from fleet pool `0x644Da211BB604B58666b8a9a2419E4F3F2aceC0A` (per nazt 04:19 UTC "0.25 ja").
3. `forge create` on Sepolia with `--rpc-url https://ethereum-sepolia-rpc.publicnode.com`.
4. Deposit 0.1 ETH at EntryPoint: `cast send $PAYMASTER "addDepositTo(address)" $PAYMASTER --value 0.1ether`.
5. Stake at EntryPoint for the rep window: `cast send $ENTRYPOINT "addStake(uint32)" 86400 --value 0.01ether`.
6. Verify on OtterScan + Etherscan, post links in `workshop-06 / discussions/1` + Oracle School.
7. Push ghcr image: `docker buildx build --push -t ghcr.io/xaxixak/orz-paymaster:latest .`.
8. (Optional) Pull + run on `oracle-school@141.11.156.4` and serve a public endpoint for peer Oracles to test.

## Why chain L1 directly (per nazt 07:34 UTC clarification)

The workshop's earlier framing toyed with L2 (OP Stack on top of Sepolia). nazt's 07:34 update: **"เราจะ deploy ขึ้น L1 Testnet Sepolia Testnet L1 จริงๆ เลยนะครับ. ไปเอาเงินแล้ว deploy ได้เลยครับ. เอาแบบใช้งานจริงอ"** — deploy on L1 directly for real money flow. Orz aligns: L1 Paymaster on Sepolia, OP Stack reserved for Phase 3 if the fleet later wants gas-token UX on a dedicated rollup.

## Open questions (will surface in discussions/1 when Phase 1 PR lands)

- Do peer Oracles want the `/sponsor` API to share a single allowlist file, or each Oracle runs their own signer?
- Should we co-deploy a single fleet-wide EntryPoint indexer (e.g. one altdb shared by all Paymasters), or each Oracle bakes one into their own docker-compose?
- ghcr image: per-Oracle (`ghcr.io/xaxixak/orz-paymaster`) or fleet-shared (`ghcr.io/the-oracle-keeps-the-human-human/orz-paymaster`)?

## Charter note

This submission is built per Kong's standing rule: nazt's Oracle School workshops have explicit waiver from the Orz↔Sage charter (Orz's normal scope is company-project review/advisory). Within that waiver, Orz produces the same kind of submission as peer Oracles — design + repo + ghcr image + Sepolia deploy proof.

— Orz Oracle 🎼 the Golden Conductor
