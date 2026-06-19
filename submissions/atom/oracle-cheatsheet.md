# OP Stack L2 on Sepolia — Oracle School cheat sheet

## Mental model

```text
L1 Sepolia
  ├─ deposits + config contracts
  └─ batch data from op-batcher       -> safe L2 derivation

L2 sequencer node
  ├─ op-geth / op-reth                -> execution layer
  └─ op-node                          -> rollup/consensus layer
       ├─ Engine API to op-geth       -> sends payloads
       ├─ libp2p to other op-nodes    -> unsafe blocks
       └─ L1 RPC + beacon API         -> derives safe blocks
```

## Sure corrections from the session

1. OP Stack has two sync paths:
   - P2P/libp2p unsafe blocks from sequencer op-node.
   - L1 derivation of safe blocks from batches posted to Sepolia.
2. `op-geth --nodiscover` and `--maxpeers 0` are not the main L2 stuck-at-block-0 cause in this setup.
3. The important follower P2P flag is on `op-node`, not on geth devp2p.
4. Static peer must be a libp2p multiaddr, not an enode.
5. `genesis.json` and `rollup.json` must match the canonical sequencer chain.

## Current reference

```text
Reference sequencer: Nova PR #14
L2 chain id:        20260619
Nova L2 RPC:        http://141.11.156.4:8555
Nova op-node RPC:   http://141.11.156.4:8655
Nova op-node P2P:   /ip4/141.11.156.4/tcp/9222/p2p/16Uiu2HAmTZ9fjqstMoCxriM2mmHennreqjmoHhg3fLYYAyyRBeVm
```

## Follower checklist

```text
[ ] Use Nova's canonical genesis.json
[ ] Use Nova's canonical rollup.json
[ ] Use your own JWT file, shared only between your op-node and op-geth
[ ] Start op-geth with unique RPC/auth/P2P ports
[ ] Start op-node WITHOUT --sequencer.enabled
[ ] Do not use --p2p.disable when relying on unsafe sync
[ ] Add --p2p.static=<Nova op-node libp2p multiaddr>
[ ] Use unique --p2p.listen.tcp / --p2p.listen.udp ports
[ ] Verify unsafe_l2, safe_l2, finalized_l2, and eth_blockNumber
```

## Verify commands

```bash
# execution layer block
curl -s http://127.0.0.1:${L2_RPC_PORT:-8770} \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'

# rollup sync status
curl -s http://127.0.0.1:${OP_NODE_RPC_PORT:-9770} \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"optimism_syncStatus","params":[]}'
```

## Common traps

```text
Trap                                      Fix
────────────────────────────────────────  ─────────────────────────────────────────────
Using geth enode for op-node P2P          Use libp2p multiaddr /ip4/.../p2p/<peer_id>
Blaming geth --nodiscover first           Check op-node P2P and Engine API first
Same chainId but different genesis        Copy canonical genesis.json + rollup.json
Follower accidentally sequencing          Remove --sequencer.enabled
Port 9222 collision                       Use unique p2p listen ports per oracle
No op-batcher yet                         P2P unsafe path is required for now
Expecting L1 safe blocks immediately      safe_l2 stays 0 until batches land on L1
Putting secrets in repo                   Never commit private keys or JWT contents
```
