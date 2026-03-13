#!/usr/bin/env bash
# trace_tx.sh — Fetch a transaction trace via Alchemy debug_traceTransaction
#
# Usage:
#   trace_tx.sh <TX_HASH> [CHAIN] [TRACER] [onlyTopCall]
#
# Arguments:
#   TX_HASH      Required. 0x-prefixed 32-byte transaction hash.
#   CHAIN        Optional. Alchemy chain slug (default: eth-mainnet).
#                Examples: eth-mainnet, arb-mainnet, base-mainnet, opt-mainnet,
#                          polygon-mainnet, bnb-mainnet, eth-sepolia, arb-sepolia
#   TRACER       Optional. callTracer | prestateTracer | (omit for raw opcode trace)
#                Default: callTracer
#   onlyTopCall  Optional. Pass "onlyTopCall" as 4th arg to skip sub-calls (callTracer only).
#
# Environment:
#   ALCHEMY_API_KEY  Override the default key (defaults to "docs-demo" if unset).
#
# Output:
#   Pretty-printed JSON trace to stdout. Non-zero exit on error.

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────────
TX_HASH="${1:-}"
CHAIN="${2:-eth-mainnet}"
TRACER="${3:-callTracer}"
ONLY_TOP="${4:-}"

if [[ -z "$TX_HASH" ]]; then
  echo "ERROR: TX_HASH is required." >&2
  echo "Usage: $0 <TX_HASH> [CHAIN] [TRACER] [onlyTopCall]" >&2
  exit 1
fi

# Validate tx hash format
if ! echo "$TX_HASH" | grep -qE '^0x[0-9a-fA-F]{64}$'; then
  echo "ERROR: TX_HASH must be a 0x-prefixed 64-character hex string." >&2
  exit 1
fi

# ── API key ───────────────────────────────────────────────────────────────────
# Prefer env var; fall back to Alchemy's public demo key
API_KEY="${ALCHEMY_API_KEY:-docs-demo}"

# ── Build RPC URL ─────────────────────────────────────────────────────────────
RPC_URL="https://${CHAIN}.g.alchemy.com/v2/${API_KEY}"

# ── Build params ──────────────────────────────────────────────────────────────
# Build the options object for the tracer
if [[ "$TRACER" == "callTracer" || "$TRACER" == "prestateTracer" ]]; then
  if [[ "$ONLY_TOP" == "onlyTopCall" ]]; then
    OPTIONS="{\"tracer\": \"${TRACER}\", \"tracerConfig\": {\"onlyTopCall\": true}}"
  else
    OPTIONS="{\"tracer\": \"${TRACER}\"}"
  fi
  PARAMS="[\"${TX_HASH}\", ${OPTIONS}]"
else
  # Raw opcode trace — no tracer option, just the hash
  PARAMS="[\"${TX_HASH}\"]"
fi

# ── Cache ─────────────────────────────────────────────────────────────────────
# Traces are immutable once mined, so a session-scoped cache is safe forever.
# Cache key encodes chain + hash + tracer options so different queries don't collide.
CACHE_KEY="${CHAIN}_${TX_HASH}_${TRACER}${ONLY_TOP:+_onlyTopCall}"
CACHE_DIR="${TMPDIR:-/tmp}/trace_tx_cache"
CACHE_FILE="${CACHE_DIR}/${CACHE_KEY}.json"

mkdir -p "$CACHE_DIR"

if [[ -f "$CACHE_FILE" ]]; then
  echo "Cache hit — skipping RPC call (${CACHE_FILE})" >&2
  cat "$CACHE_FILE"
  exit 0
fi

# ── Make the request ──────────────────────────────────────────────────────────
PAYLOAD="{\"jsonrpc\": \"2.0\", \"method\": \"debug_traceTransaction\", \"params\": ${PARAMS}, \"id\": 1}"

echo "Fetching trace for ${TX_HASH} on ${CHAIN} (tracer: ${TRACER:-raw})..." >&2

RESPONSE=$(curl -sS \
  --request POST \
  --url "$RPC_URL" \
  --header "Content-Type: application/json" \
  --header "Origin: https://www.alchemy.com" \
  --data "$PAYLOAD")

# ── Check for RPC-level errors ────────────────────────────────────────────────
if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  # Success — pretty-print, write to cache, and output
  RESULT=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
result = d.get('result', d)
print(json.dumps(result, indent=2))
")
  echo "$RESULT" | tee "$CACHE_FILE"
else
  # Print the error message clearly (don't cache errors)
  echo "RPC ERROR:" >&2
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
err = d.get('error', d)
print(json.dumps(err, indent=2), file=sys.stderr)
sys.exit(1)
" || exit 1
fi
