#!/usr/bin/env bash
# trace_tx.sh — Fetch a transaction trace via debug_traceTransaction
#
# Usage:
#   trace_tx.sh [-o <output_file>] <TX_HASH> <RPC_URL> [TRACER] [onlyTopCall]
#
# Options:
#   -o <file>    Write JSON output to <file> instead of stdout.
#
# Arguments:
#   TX_HASH      Required. 0x-prefixed 32-byte transaction hash.
#   RPC_URL      Required. Full RPC endpoint URL.
#   TRACER       Optional. callTracer | prestateTracer | (omit for raw opcode trace)
#                Default: callTracer
#   onlyTopCall  Optional. Pass "onlyTopCall" as 4th arg to skip sub-calls (callTracer only).
#
# Output:
#   Pretty-printed JSON trace to stdout (or file if -o is given). Non-zero exit on error.

set -euo pipefail

# ── Options ───────────────────────────────────────────────────────────────────
OUTPUT_FILE=""
while getopts ":o:" opt; do
  case $opt in
    o) OUTPUT_FILE="$OPTARG" ;;
    :) echo "ERROR: -$OPTARG requires an argument." >&2; exit 1 ;;
    \?) echo "ERROR: Unknown option -$OPTARG." >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# ── Arguments ─────────────────────────────────────────────────────────────────
TX_HASH="${1:-}"
RPC_URL="${2:-}"
TRACER="${3:-callTracer}"
ONLY_TOP="${4:-}"

if [[ -z "$TX_HASH" ]]; then
  echo "ERROR: TX_HASH is required." >&2
  echo "Usage: $0 [-o <output_file>] <TX_HASH> <RPC_URL> [TRACER] [onlyTopCall]" >&2
  exit 1
fi

# Validate tx hash format
if ! echo "$TX_HASH" | grep -qE '^0x[0-9a-fA-F]{64}$'; then
  echo "ERROR: TX_HASH must be a 0x-prefixed 64-character hex string." >&2
  exit 1
fi

if [[ -z "$RPC_URL" ]]; then
  echo "ERROR: RPC_URL is required." >&2
  echo "Usage: $0 [-o <output_file>] <TX_HASH> <RPC_URL> [TRACER] [onlyTopCall]" >&2
  exit 1
fi

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

# ── Make the request ──────────────────────────────────────────────────────────
PAYLOAD="{\"jsonrpc\": \"2.0\", \"method\": \"debug_traceTransaction\", \"params\": ${PARAMS}, \"id\": 1}"

echo "Fetching trace for ${TX_HASH} (tracer: ${TRACER:-raw})..." >&2

do_request() {
  local url="$1"
  curl -sS \
    --request POST \
    --url "$url" \
    --header "Content-Type: application/json" \
    --data "$PAYLOAD"
}

RESPONSE=$(do_request "$RPC_URL")

# ── Check for RPC-level errors ────────────────────────────────────────────────
# Guard against non-JSON responses (plain-text errors from the provider)
if ! echo "$RESPONSE" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "RPC ERROR (non-JSON response):" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  # Success — pretty-print and output
  RESULT=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
result = d.get('result', d)
print(json.dumps(result, indent=2))
")
  if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s\n' "$RESULT" > "$OUTPUT_FILE"
    echo "Trace written to ${OUTPUT_FILE}" >&2
  else
    printf '%s\n' "$RESULT"
  fi
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
