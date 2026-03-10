---
name: fetch-source
description: Fetches verified smart contract source code from Sourcify and Etherscan for any EVM-compatible chain. Use this skill whenever the user wants to download, retrieve, or inspect the source code of a smart contract at a given address, audit a contract, or analyze on-chain code — even if they don't say "Sourcify" or "Etherscan" explicitly.
---

# Fetch Source

Fetches verified smart contract source code from Sourcify and Etherscan for any EVM-compatible chain.

## Usage

```
./scripts/fetch_sources.sh -c <chain_id> [-o <output_dir>] <address>
```

**Optional environment variable:** `ETHERSCAN_API_KEY` (enables Etherscan fallback if not found on Sourcify)

## What it does

1. Tries **Sourcify** first (no API key needed)
2. Falls back to **Etherscan v2 API** if not found on Sourcify
3. Saves all source files under `sources_<address>/` (or custom `-o` dir)

Handles all Etherscan source formats: standard JSON input (with or without extra braces), and single flat files. Detects Vyper vs Solidity by compiler version.

## Examples

```bash
# Fetch Uniswap V3 Factory on Ethereum (chain 1)
./scripts/fetch_sources.sh -c 1 0x1F98431c8aD98523631AE4a59f267346ea31F984

# Custom output directory
./scripts/fetch_sources.sh -c 137 -o ./uniswap_polygon 0x1F98431c8aD98523631AE4a59f267346ea31F984
```

## Chain IDs

Common chain IDs: `1` (Ethereum), `10` (Optimism), `56` (BSC), `137` (Polygon), `8453` (Base), `42161` (Arbitrum)

## Output

- `sources_<address>/sourcify.json` or `etherscan.json` — raw API response
- `sources_<address>/<filepath>.sol` — individual source files as returned by the verifier
