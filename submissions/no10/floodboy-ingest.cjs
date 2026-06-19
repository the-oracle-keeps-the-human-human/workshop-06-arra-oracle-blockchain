#!/usr/bin/env node
/**
 * floodboy-ingest — download/backfill FloodBoy sensor records from JIBChain.
 * P'Nat ask 2026-06-12: "create download backfill data + keep maw hey every 1h"
 *
 * Modes:
 *   node floodboy-ingest.cjs backfill [maxStores]   # full history from deploy block
 *   node floodboy-ingest.cjs incremental            # only new records since saved state
 *
 * Source: factory 0x63bB...a5Bb on JIBCHAIN L1 (8899). Per-store RecordStored events.
 * Output: data/<store>.jsonl  (one JSON record per line) + state.json (last block per store)
 *         data/_fields/<store>.json (field schema, fetched once)
 * Reads only — no key, no gas. Chunked getLogs w/ retry-halving for RPC range limits.
 */
const fs = require('fs');
const path = require('path');
const { createPublicClient, http, parseAbiItem, fallback } = require('viem');

const FACTORY = '0x63bB41b79b5aAc6e98C7b35Dcb0fE941b85Ba5Bb';
const DEPLOY_BLOCK = 5940322n;
const RPCS = ['https://rpc-l1.jibchain.net', 'https://rpc-l1.inan.in.th'];
const DIR = path.join(__dirname, 'data');
const FIELDS_DIR = path.join(DIR, '_fields');
const STATE = path.join(__dirname, 'state.json');

const jibchain = { id: 8899, name: 'JIBCHAIN L1', nativeCurrency: { name: 'JBC', symbol: 'JBC', decimals: 18 },
  rpcUrls: { default: { http: RPCS } } };
const client = createPublicClient({ chain: jibchain, transport: fallback(RPCS.map((u) => http(u))) });

const RECORD_STORED = parseAbiItem('event RecordStored(address indexed signer, uint256 timestamp, int256[] values)');
const FACTORY_ABI = [
  parseAbiItem('function allStoresCount() view returns (uint32)'),
  parseAbiItem('function getStores(uint256 start, uint256 count) view returns (address[])'),
];
const STORE_FIELDS = parseAbiItem('function getAllFields() view returns ((string,string,string)[])');

const loadState = () => { try { return JSON.parse(fs.readFileSync(STATE, 'utf8')); } catch { return {}; } };
const saveState = (s) => fs.writeFileSync(STATE, JSON.stringify(s, null, 2));
const log = (m) => console.log(`${new Date().toISOString()} ${m}`);

async function getStores() {
  const count = await client.readContract({ address: FACTORY, abi: FACTORY_ABI, functionName: 'allStoresCount' });
  const out = [];
  for (let i = 0; i < Number(count); i += 100) {
    const batch = await client.readContract({ address: FACTORY, abi: FACTORY_ABI, functionName: 'getStores', args: [BigInt(i), 100n] });
    out.push(...batch);
  }
  return out;
}

async function fetchFields(store) {
  const fp = path.join(FIELDS_DIR, `${store}.json`);
  if (fs.existsSync(fp)) return;
  try {
    const fields = await client.readContract({ address: store, abi: [STORE_FIELDS], functionName: 'getAllFields' });
    fs.writeFileSync(fp, JSON.stringify(fields.map((f) => ({ name: f[0], unit: f[1], dtype: f[2] })), null, 2));
  } catch (e) { log(`  fields fail ${store}: ${e.shortMessage || e.message}`); }
}

// chunked getLogs with halving on RPC range errors
async function logsInChunks(store, fromBlock, toBlock) {
  const all = [];
  let from = fromBlock, size = 9000n;
  while (from <= toBlock) {
    const to = (from + size - 1n) > toBlock ? toBlock : (from + size - 1n);
    try {
      const logs = await client.getLogs({ address: store, event: RECORD_STORED, fromBlock: from, toBlock: to });
      all.push(...logs);
      from = to + 1n;
      if (size < 50000n) size *= 2n; // recover after a successful smaller chunk
    } catch (e) {
      if (size > 1000n) { size /= 2n; continue; }   // shrink range, retry
      log(`  getLogs hard-fail ${store} ${from}-${to}: ${e.shortMessage || e.message}`); from = to + 1n;
    }
  }
  return all;
}

async function ingestStore(store, fromBlock, toBlock, state) {
  await fetchFields(store);
  const logs = await logsInChunks(store, fromBlock, toBlock);
  if (logs.length) {
    const lines = logs.map((l) => JSON.stringify({
      block: Number(l.blockNumber), tx: l.transactionHash, signer: l.args.signer,
      timestamp: Number(l.args.timestamp), values: l.args.values.map((v) => v.toString()),
    })).join('\n') + '\n';
    fs.appendFileSync(path.join(DIR, `${store}.jsonl`), lines);
  }
  state[store] = Number(toBlock);
  return logs.length;
}

async function main() {
  const mode = process.argv[2] || 'incremental';
  const maxStores = process.argv[3] ? Number(process.argv[3]) : Infinity;
  fs.mkdirSync(FIELDS_DIR, { recursive: true });
  const state = loadState();
  const head = await client.getBlockNumber();
  let stores = await getStores();
  stores = stores.slice(0, maxStores);
  log(`mode=${mode} stores=${stores.length} head=${head}`);

  let totalNew = 0, withData = 0;
  for (let i = 0; i < stores.length; i++) {
    const store = stores[i];
    const from = mode === 'backfill' ? DEPLOY_BLOCK : BigInt((state[store] ?? Number(DEPLOY_BLOCK)) + 1);
    if (from > head) { continue; }
    const n = await ingestStore(store, from, head, state);
    totalNew += n; if (n) withData++;
    saveState(state); // checkpoint after each store (resumable)
    if ((i + 1) % 10 === 0 || n) log(`  [${i + 1}/${stores.length}] ${store} +${n} records`);
  }
  log(`DONE ${mode}: ${totalNew} new records across ${withData}/${stores.length} stores. head=${head}`);
  // machine-readable summary line for the poller wrapper
  console.log(`SUMMARY new=${totalNew} stores_with_data=${withData} total_stores=${stores.length} head=${head}`);
}

main().catch((e) => { log(`FATAL ${e.stack || e.message}`); process.exit(1); });
