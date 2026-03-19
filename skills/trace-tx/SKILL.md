---
name: trace-tx
description: >
  Fetches the full execution trace of an EVM transaction using debug_traceTransaction API.
  Use this skill whenever the user wants to trace a transaction, inspect internal calls, debug a failed
  tx, check sub-calls or revert reasons, analyze gas usage per call, understand what a transaction
  actually did on-chain, or investigate MEV / sandwich attacks. Trigger even if the user just says
  things like "trace this tx", "what did this transaction do?", "why did this tx revert?",
  "show me the call tree", or "get the internal calls for 0x...".
---

# trace-tx

Fetches the full execution trace for an EVM transaction via `debug_traceTransaction`. The trace reveals the complete call tree: every internal CALL/DELEGATECALL/CREATE, gas consumed at each step, input/output data, and any revert reasons.

## Usage

```bash
~/.claude/skills/trace-tx/scripts/trace_tx.sh [-o <output_file>] <TX_HASH> <RPC_URL> [TRACER] [onlyTopCall]
```

- Use the RPC URL the user supplied.
- Or if `ALCHEMY_API_KEY` is set, construct the Alchemy URL: `https://<chain-slug>.g.alchemy.com/v2/$ALCHEMY_API_KEY` and use it as the RPC URL. Common slugs: "Ethereum"/"ETH" → `eth-mainnet`, "Arbitrum"/"Arb" → `arb-mainnet`, "Base" → `base-mainnet`, "Optimism"/"OP" → `opt-mainnet`, "Polygon"/"MATIC" → `polygon-mainnet`, "BSC"/"BNB Chain" → `bnb-mainnet`, "Sepolia" → `eth-sepolia`. Find full slug list in `references/rpc_urls.md` only when necessary.
- If neither is available, find an RPC URL that supports `debug_traceTransaction` for the specific tx.
- Default tracer: `callTracer` (nested call tree — best for most tasks). Also supports `prestateTracer` and raw opcode trace.

## Workflow

Use `-o` to write the trace to a file — traces can be megabytes:

```bash
~/.claude/skills/trace-tx/scripts/trace_tx.sh -o trace_0xabc123.json 0xabc... https://your-rpc-url
```

Tell the user the path to the saved file.

## Reference

- Full RPC URL list: `references/rpc_urls.md`
