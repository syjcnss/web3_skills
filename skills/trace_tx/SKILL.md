---
name: trace_tx
description: >
  Fetches the full execution trace of an EVM transaction using debug_traceTransaction API.
  Use this skill whenever the user wants to trace a transaction, inspect internal calls, debug a failed
  tx, check sub-calls or revert reasons, analyze gas usage per call, understand what a transaction
  actually did on-chain, or investigate MEV / sandwich attacks. Trigger even if the user just says
  things like "trace this tx", "what did this transaction do?", "why did this tx revert?",
  "show me the call tree", or "get the internal calls for 0x...".
---

# trace_tx

Fetches the full execution trace for an EVM transaction via `debug_traceTransaction` JSON-RPC method. The trace reveals the complete call tree: every internal CALL/DELEGATECALL/CREATE, gas consumed at each step, input/output data, and any revert reasons.

## Quick start

Use the bundled script — it handles RPC selection, API key injection, caching, and pretty-printing:

```bash
~/.claude/skills/trace_tx/scripts/trace_tx.sh <TX_HASH> [CHAIN] [TRACER] [onlyTopCall]
```

**Examples:**
```bash
# Trace on Ethereum mainnet (default)
~/.claude/skills/trace_tx/scripts/trace_tx.sh 0xabc123...

# Trace on Arbitrum by chain name
~/.claude/skills/trace_tx/scripts/trace_tx.sh 0xabc123... arb-mainnet

# Use a custom RPC URL — CHAIN argument is not needed
RPC_URL=https://my-node.example.com/rpc ~/.claude/skills/trace_tx/scripts/trace_tx.sh 0xabc123...

# prestateTracer via custom RPC
RPC_URL=https://my-node.example.com/rpc ~/.claude/skills/trace_tx/scripts/trace_tx.sh 0xabc123... "" prestateTracer

# Only top-level call (faster, less noise)
~/.claude/skills/trace_tx/scripts/trace_tx.sh 0xabc123... eth-mainnet callTracer onlyTopCall
```

## RPC provider

**If the user provides a full RPC URL** (e.g. their own node, Infura, QuickNode, etc.), pass it via the `RPC_URL` environment variable. CHAIN is ignored when `RPC_URL` is set.

**Otherwise**, the script builds the Alchemy URL from the CHAIN slug. It uses `ALCHEMY_API_KEY` from the environment, falling back to `docs-demo` (Alchemy's public demo key) if unset.

When to use `RPC_URL`:
- User says "use my own node at https://..."
- User provides a non-Alchemy endpoint (Infura, QuickNode, Tenderly, etc.)
- User wants to avoid Alchemy entirely

## Caching

The script caches results in `/tmp/trace_tx_cache/` keyed by chain + tx hash + tracer options. Subsequent calls for the same query return instantly without hitting Alchemy. Since on-chain traces are immutable, cached data is always valid. To force a fresh fetch, delete the relevant cache file or clear the directory with `rm -rf /tmp/trace_tx_cache/`.

## Chain selection

The CHAIN argument maps to an Alchemy subdomain. Common values:

| Chain argument      | Network                  |
|---------------------|--------------------------|
| `eth-mainnet`       | Ethereum Mainnet (default)|
| `arb-mainnet`       | Arbitrum One             |
| `base-mainnet`      | Base Mainnet             |
| `opt-mainnet`       | OP Mainnet               |
| `polygon-mainnet`   | Polygon Mainnet          |
| `bnb-mainnet`       | BNB Smart Chain          |

Full list of supported chains is in `references/rpc_urls.md`. If the user mentions a chain by name (e.g., "on Base"), map it to the appropriate chain slug automatically.

## Tracer options

| Tracer           | What it gives you                                              |
|------------------|----------------------------------------------------------------|
| `callTracer`     | Nested call tree (type, from, to, value, gas, input, output, error). Best for understanding what happened. **Default.** |
| `prestateTracer` | The state of every account/storage slot touched *before* the tx ran. Useful for replaying or diffing state. |
| *(default)*      | Raw EVM opcode-level trace (huge output — avoid unless you need step-by-step opcodes). |

## Workflow

1. **Run the script** to fetch the raw trace JSON.
2. **Parse the output** to answer the user's question:
   - Revert reason → look for `"error"` / `"revertReason"` in any call frame.
   - Internal transfers → find CALL frames with non-zero `value`.
   - Gas hotspots → compare `gasUsed` across frames.
   - Sub-contracts called → collect all unique `to` addresses.
3. **Present findings** clearly. For deep call trees, summarize the top-level flow first, then drill into the interesting frames.

## Interpreting the callTracer output

```json
{
  "type": "CALL",          // CALL | DELEGATECALL | STATICCALL | CREATE | CREATE2
  "from": "0xSENDER",
  "to":   "0xRECIPIENT",
  "value": "0x...",        // ETH transferred (hex wei)
  "gas":     "0x...",      // gas provided
  "gasUsed": "0x...",      // gas actually consumed
  "input":   "0x...",      // calldata (first 4 bytes = function selector)
  "output":  "0x...",      // return data
  "error":   "...",        // present if this frame reverted
  "revertReason": "...",   // decoded Solidity revert string if available
  "calls": [ ... ]         // nested sub-calls (recursive structure)
}
```

## Error handling

- **`execution timeout`** — add `"timeout": "120s"` or use `onlyTopCall` to reduce scope.
- **`method not found`** — chain doesn't support `debug_traceTransaction`. Try Ethereum mainnet instead.
- **`transaction not found`** — wrong chain or tx hash. Double-check the chain matches where the tx was mined.
- **HTTP 401** — invalid API key. Check `ALCHEMY_API_KEY`.

## Reference

- Full RPC URL list: `references/rpc_urls.md`
- Alchemy debug_traceTransaction docs: https://www.alchemy.com/docs/node/debug-api/debug-api-endpoints/debug-trace-transaction
