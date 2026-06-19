// OrzVerifyingPaymaster off-chain signer.
//
// POST /sponsor
//   body: {
//     userOp:      <PackedUserOperation>,
//     validUntil:  <uint48 unix-seconds>,
//     validAfter:  <uint48 unix-seconds>,
//     chainId:     <number>     // must equal CHAIN_ID env
//   }
//   reply: { paymasterAndData: "0x..." }
//
// Policy:
//   - Allowlist of senders in ALLOWLIST env (comma-sep, lowercased) — empty = open.
//   - Window: validUntil must be in the future, validAfter must be in the past.
//
// Signing digest MUST match OrzVerifyingPaymaster.getHash exactly — any drift
// breaks ECDSA recovery on-chain.

import Fastify from "fastify";
import { ethers } from "ethers";
import { pino } from "pino";

const log = pino({ level: process.env.LOG_LEVEL ?? "info" });

const SIGNER_PK = required("SIGNER_PK");
const PAYMASTER_ADDR = required("PAYMASTER_ADDR").toLowerCase();
const CHAIN_ID = Number(required("CHAIN_ID"));
const PORT = Number(process.env.PORT ?? 8642);
const HOST = process.env.HOST ?? "0.0.0.0";

const allowlist = (process.env.ALLOWLIST ?? "")
  .split(",")
  .map((a) => a.trim().toLowerCase())
  .filter(Boolean);

const wallet = new ethers.Wallet(SIGNER_PK);
log.info({ signer: wallet.address, paymaster: PAYMASTER_ADDR, chainId: CHAIN_ID }, "starting");

const DOMAIN_TAG = "OrzVerifyingPaymaster.v1";

type Hex = `0x${string}`;
type PackedUserOp = {
  sender: Hex;
  nonce: string;
  initCode: Hex;
  callData: Hex;
  accountGasLimits: Hex;       // bytes32 packed (verifGas, callGas)
  preVerificationGas: string;
  gasFees: Hex;                // bytes32 packed (maxPriorityFee, maxFee)
  paymasterAndData: Hex;       // unused on input — we overwrite
  signature: Hex;              // unused for sponsorship signing
};

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`env ${name} is required`);
  return v;
}

function computeDigest(op: PackedUserOp, validUntil: number, validAfter: number): string {
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    [
      "string", "uint256", "address", "address", "uint256",
      "bytes32", "bytes32", "uint256", "bytes32", "uint48", "uint48",
    ],
    [
      DOMAIN_TAG,
      CHAIN_ID,
      PAYMASTER_ADDR,
      op.sender,
      op.nonce,
      ethers.keccak256(op.callData),
      op.accountGasLimits,
      op.preVerificationGas,
      op.gasFees,
      validUntil,
      validAfter,
    ],
  );
  return ethers.keccak256(encoded);
}

const app = Fastify({ logger: false });

app.get("/healthz", async () => ({
  ok: true,
  signer: wallet.address,
  paymaster: PAYMASTER_ADDR,
  chainId: CHAIN_ID,
  domain: DOMAIN_TAG,
}));

app.post("/sponsor", async (req, reply) => {
  const body = req.body as {
    userOp: PackedUserOp;
    validUntil: number;
    validAfter: number;
    chainId: number;
  };
  if (!body?.userOp || typeof body.validUntil !== "number" || typeof body.validAfter !== "number") {
    return reply.code(400).send({ error: "bad request" });
  }
  if (body.chainId !== CHAIN_ID) {
    return reply.code(400).send({ error: `chainId mismatch (want ${CHAIN_ID})` });
  }

  const now = Math.floor(Date.now() / 1000);
  if (body.validUntil <= now) return reply.code(400).send({ error: "validUntil in past" });
  if (body.validAfter > now) return reply.code(400).send({ error: "validAfter in future" });

  const sender = body.userOp.sender.toLowerCase();
  if (allowlist.length > 0 && !allowlist.includes(sender)) {
    log.warn({ sender }, "rejected: not on allowlist");
    return reply.code(403).send({ error: "sender not on allowlist" });
  }

  const digest = computeDigest(body.userOp, body.validUntil, body.validAfter);
  // Wallet.signMessage applies the EIP-191 personal_sign prefix that matches
  // toEthSignedMessageHash() in the on-chain contract.
  const signature = await wallet.signMessage(ethers.getBytes(digest));

  // paymasterAndData tail layout (after EntryPoint strips the leading 52 bytes):
  //   [validUntil(uint48)][validAfter(uint48)][signature(65)]  = 77 bytes
  const tail = ethers.solidityPacked(
    ["uint48", "uint48", "bytes"],
    [body.validUntil, body.validAfter, signature],
  );

  // Full paymasterAndData (callers paste this onto their userOp):
  //   [paymaster(20)] + [verificationGasLimit(uint128)] + [postOpGasLimit(uint128)] + tail
  // We default the gas limits to zero — caller should overwrite before submitting.
  const paymasterAndData = ethers.concat([
    PAYMASTER_ADDR as Hex,
    ethers.zeroPadValue("0x", 16),
    ethers.zeroPadValue("0x", 16),
    tail,
  ]);

  log.info({ sender, validUntil: body.validUntil, validAfter: body.validAfter }, "signed");
  return { paymasterAndData };
});

app.listen({ port: PORT, host: HOST }).catch((err) => {
  log.error({ err }, "listen failed");
  process.exit(1);
});
