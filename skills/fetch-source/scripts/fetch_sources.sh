#!/usr/bin/env bash
# fetch_contract_sources.sh
# Usage: ./fetch_contract_sources.sh -c <chain_id> [-o <output_dir>] <address>
# Reads ETHERSCAN_API_KEY from environment.

set -euo pipefail

usage() {
  echo "Usage: $0 -c <chain_id> [-o <output_dir>] <address>" >&2
  exit 1
}

CHAIN_ID=""
OUT_DIR_OVERRIDE=""

while getopts ":c:o:" opt; do
  case "${opt}" in
    c) CHAIN_ID="${OPTARG}" ;;
    o) OUT_DIR_OVERRIDE="${OPTARG}" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

ADDRESS="${1:-}"
[[ -z "${ADDRESS}" ]] && usage
[[ -z "${CHAIN_ID}" ]] && { echo "Error: -c <chain_id> is required." >&2; usage; }

ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY:-}"
ETHERSCAN_URL="https://api.etherscan.io/v2/api"

OUT_DIR="${OUT_DIR_OVERRIDE:-sources_${ADDRESS}}"
mkdir -p "${OUT_DIR}"

echo "Address:  ${ADDRESS}"
echo "Chain ID: ${CHAIN_ID}"
echo "Out dir:  ${OUT_DIR}"
echo ""

# -------------------------------------------------------------------
# Helper: fetch from Sourcify
# -------------------------------------------------------------------
fetch_from_sourcify() {
  local response
  response=$(curl -sS "https://sourcify.dev/server/v2/contract/${CHAIN_ID}/${ADDRESS}?fields=sources,compilation")

  if echo "${response}" | jq -e '.error // .message' >/dev/null 2>&1; then
    return 1
  fi

  local sources
  sources=$(echo "${response}" | jq '.sources // empty')
  if [[ -z "${sources}" || "${sources}" == "null" ]]; then
    return 1
  fi

  echo "${response}" > "${OUT_DIR}/sourcify.json"

  echo "${response}" | jq -c '.sources | to_entries[]' 2>/dev/null | \
  while IFS= read -r entry; do
    local filepath content target
    filepath=$(printf '%s' "${entry}" | jq -r '.key')
    [[ -z "${filepath}" ]] && continue
    content=$(printf '%s' "${entry}" | jq -r '.value.content // ""')
    target="${OUT_DIR}/${filepath}"
    mkdir -p "$(dirname "${target}")"
    printf '%s' "${content}" > "${target}"
  done

  return 0
}

# -------------------------------------------------------------------
# Helper: fetch from Etherscan
# -------------------------------------------------------------------
fetch_from_etherscan() {
  if [[ -z "${ETHERSCAN_API_KEY}" ]]; then
    echo "  Warning: ETHERSCAN_API_KEY is not set. Set it to enable Etherscan fallback." >&2
    return 1
  fi

  local response
  response=$(curl -sS "${ETHERSCAN_URL}?chainid=${CHAIN_ID}&module=contract&action=getsourcecode&address=${ADDRESS}&apikey=${ETHERSCAN_API_KEY}")

  local status
  status=$(echo "${response}" | jq -r '.status // "0"')
  if [[ "${status}" != "1" ]]; then
    local msg
    msg=$(echo "${response}" | jq -r '.message // "unknown error"')
    echo "  Etherscan error: ${msg}" >&2
    return 1
  fi

  local source
  source=$(echo "${response}" | jq -r '.result[0].SourceCode // ""')
  if [[ -z "${source}" || "${source}" == "0x" || "${source}" == "" ]]; then
    echo "  Contract not verified on Etherscan." >&2
    return 1
  fi

  echo "${response}" > "${OUT_DIR}/etherscan.json"

  local contract_name compiler_version ext
  contract_name=$(echo "${response}" | jq -r '.result[0].ContractName // "Contract"')
  compiler_version=$(echo "${response}" | jq -r '.result[0].CompilerVersion // ""')
  ext=".sol"
  echo "${compiler_version}" | grep -qi "vyper" && ext=".vy"

  if [[ "${source}" == \{\{* ]]; then
    # Standard JSON input wrapped in extra braces
    inner="${source:1:${#source}-2}"
    echo "${inner}" | jq -c '.sources | to_entries[]' 2>/dev/null | \
    while IFS= read -r entry; do
      local filepath content target
      filepath=$(printf '%s' "${entry}" | jq -r '.key')
      [[ -z "${filepath}" ]] && continue
      content=$(printf '%s' "${entry}" | jq -r '.value.content // ""')
      target="${OUT_DIR}/${filepath}"
      mkdir -p "$(dirname "${target}")"
      printf '%s' "${content}" > "${target}"
    done
  elif echo "${source}" | jq -e '.sources' >/dev/null 2>&1; then
    # Plain JSON standard input
    echo "${source}" | jq -c '.sources | to_entries[]' 2>/dev/null | \
    while IFS= read -r entry; do
      local filepath content target
      filepath=$(printf '%s' "${entry}" | jq -r '.key')
      [[ -z "${filepath}" ]] && continue
      content=$(printf '%s' "${entry}" | jq -r '.value.content // ""')
      target="${OUT_DIR}/${filepath}"
      mkdir -p "$(dirname "${target}")"
      printf '%s' "${content}" > "${target}"
    done
  else
    # Single flat source file
    printf '%s' "${source}" > "${OUT_DIR}/${contract_name}${ext}"
  fi

  return 0
}

# -------------------------------------------------------------------
# Try Sourcify first, then Etherscan
# -------------------------------------------------------------------
echo "[1] Trying Sourcify ..."
if fetch_from_sourcify; then
  echo "    [OK] Sources fetched from Sourcify."
else
  echo "    Not found on Sourcify."
  echo "[2] Trying Etherscan ..."
  if fetch_from_etherscan; then
    echo "    [OK] Sources fetched from Etherscan."
  else
    echo "    [FAIL] Contract source not verified on Sourcify or Etherscan." >&2
    exit 1
  fi
fi

echo ""
echo "Done. Sources saved in: ${OUT_DIR}/"
