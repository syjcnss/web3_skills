---
name: dune2
description: "Focused Dune CLI skill for on-chain investigation queries that are hard or impossible via RPC: finding token transfers from/to a specific address (across all tokens), locating a contract's creation transaction, finding all transactions that called a specific function on a contract, filtering/searching logs by contract or event, and looking up labels/names for any Ethereum address. Use this skill whenever the user wants to search for transactions meeting specific conditions, find who interacted with a contract, trace token flows for a wallet, look up contract deployment, filter events, or identify an address — especially when they say things like 'find all txs that called X', 'show token transfers for address', 'when was this contract deployed', 'search for logs', 'who called this function', 'what is this address', 'label for address', or 'who owns this wallet'."
allowed-tools: Bash(dune:*)
---

## Overview

This skill covers five focused use cases where Dune excels over RPC:

1. [Token transfers from/to an address](#1-token-transfers-fromto-an-address)
2. [Contract creation transaction](#2-contract-creation-transaction)
3. [All txs that called a specific function](#3-all-txs-that-called-a-specific-function)
4. [Filter logs by contract or event](#4-filter-logs-by-contract-or-event)
5. [Labels for an address](#5-labels-for-an-address)

## Prerequisites

Assume Dune CLI is installed and authenticated. Run commands directly.

If a command fails:
- `"command not found"` → CLI not installed
- `401 / "unauthorized"` → Auth failure (set `DUNE_API_KEY` env var or run `dune auth --api-key <key>`)
- Always use `-o json` for all commands

**Critical DuneSQL rules:**
- Addresses are `varbinary` — use `0x` prefix without quotes: `WHERE "from" = 0xabc...` (NOT `'0xabc...'`)
- Reserve words `from` and `to` must be quoted: `"from"`, `"to"`
- Always include a partition filter (`block_time`, `evt_block_time`) to avoid scanning the full table
- For `tokens.transfers` spell table, the partition column is `block_time`

**Chain names** used as table prefixes and `blockchain` column values:
`ethereum`, `base`, `arbitrum`, `optimism`, `polygon`, `bnb`, `avalanche_c`, `gnosis`, `fantom`, `scroll`, `zksync`, `linea`, `mantle`, `blast`, `celo`

When the user doesn't specify a chain, ask — or default to querying across all chains using spell tables (`tokens.transfers`, `dex.trades`) which already include a `blockchain` column.

---

## 1. Token Transfers From/To an Address

Use the `tokens.transfers` spell table — it aggregates ERC-20/721/1155 transfers across all tokens, already decoded with symbol, amount, and USD value.

```bash
dune query run-sql --sql "
SELECT
  block_time,
  blockchain,
  symbol,
  amount,
  amount_usd,
  \"from\",
  \"to\",
  tx_hash,
  contract_address
FROM tokens.transfers
WHERE (
  \"from\" = 0xTARGET_ADDRESS
  OR \"to\" = 0xTARGET_ADDRESS
)
AND blockchain = 'ethereum'
AND block_time >= NOW() - INTERVAL '30' DAY
ORDER BY block_time DESC
LIMIT 100
" -o json
```

**Customize:**
- Change `blockchain` to `base`, `arbitrum`, `optimism`, `polygon`, `bnb`, etc.
- Remove the `blockchain` filter to search all chains
- Adjust the `INTERVAL` for time range
- Add `AND symbol = 'USDC'` to filter by token
- Add `AND amount_usd > 1000` to filter by USD value

**For a specific token contract on a specific chain** (if you know both):
```bash
# Replace erc20_<chain> with e.g. erc20_base, erc20_arbitrum, erc20_optimism, erc20_polygon, erc20_bnb, etc.
dune query run-sql --sql "
SELECT
  evt_block_time,
  \"from\",
  \"to\",
  CAST(value AS double) / POWER(10, 18) AS amount,
  evt_tx_hash
FROM erc20_<chain>.evt_Transfer
WHERE (\"from\" = 0xTARGET OR \"to\" = 0xTARGET)
AND contract_address = 0xTOKEN_CONTRACT
AND evt_block_time >= NOW() - INTERVAL '30' DAY
ORDER BY evt_block_time DESC
LIMIT 100
" -o json
```

---

## 2. Contract Creation Transaction

Find when and how a contract was deployed. Replace `<chain>` with the appropriate chain name.

```bash
# <chain> = ethereum | base | arbitrum | optimism | polygon | bnb | avalanche_c | etc.
dune query run-sql --sql "
SELECT
  block_time,
  block_number,
  tx_hash,
  \"from\" AS deployer,
  address AS contract_address
FROM <chain>.creation_traces
WHERE address = 0xCONTRACT_ADDRESS
" -o json
```

> No time filter needed — filtering on `address` is lightweight. If you don't know which chain, check a few or use a block explorer first.

---

## 3. All Txs That Called a Specific Function

**Option A — Use decoded call tables (preferred if available)**

First, find if the contract has decoded tables:
```bash
dune dataset search-by-contract --contract-address 0xCONTRACT_ADDRESS --include-schema -o json
```

Look for `call_<FunctionName>` tables (e.g. `call_swap`, `call_transfer`). The namespace includes the chain (e.g. `uniswap_v3_ethereum`, `uniswap_v3_base`). Then query:
```bash
dune query run-sql --sql "
SELECT
  call_block_time,
  call_tx_hash,
  call_success,
  output_0,
  -- add decoded input columns as needed
  call_from
FROM <namespace>.call_<FunctionName>
WHERE call_block_time >= NOW() - INTERVAL '30' DAY
ORDER BY call_block_time DESC
LIMIT 100
" -o json
```

**Option B — Filter by function selector from raw traces** (works for any contract, any chain)

The function selector is the first 4 bytes of calldata (keccak256 of the function signature).

```bash
# <chain> = ethereum | base | arbitrum | optimism | polygon | bnb | avalanche_c | etc.
dune query run-sql --sql "
SELECT
  block_time,
  tx_hash,
  \"from\",
  \"to\",
  SUBSTR(input, 1, 4) AS selector,
  input
FROM <chain>.traces
WHERE \"to\" = 0xCONTRACT_ADDRESS
AND SUBSTR(input, 1, 4) = 0xSELECTOR  -- e.g. 0xa9059cbb for transfer(address,uint256)
AND block_time >= NOW() - INTERVAL '30' DAY
AND call_type = 'call'
ORDER BY block_time DESC
LIMIT 100
" -o json
```

> Common selectors: `transfer(address,uint256)` = `0xa9059cbb`, `approve(address,uint256)` = `0x095ea7b3`

**Option C — Direct calls only (transaction-level)**:
```bash
dune query run-sql --sql "
SELECT
  block_time,
  hash AS tx_hash,
  \"from\",
  \"to\",
  value
FROM <chain>.transactions
WHERE \"to\" = 0xCONTRACT_ADDRESS
AND SUBSTR(data, 1, 4) = 0xSELECTOR
AND block_time >= NOW() - INTERVAL '30' DAY
ORDER BY block_time DESC
LIMIT 100
" -o json
```

---

## 4. Filter Logs by Contract or Event

Replace `<chain>` with the target chain name.

**All logs for a contract** (raw):
```bash
dune query run-sql --sql "
SELECT
  block_time,
  tx_hash,
  topic0,
  topic1,
  topic2,
  topic3,
  data,
  index
FROM <chain>.logs
WHERE contract_address = 0xCONTRACT_ADDRESS
AND block_time >= NOW() - INTERVAL '7' DAY
ORDER BY block_time DESC
LIMIT 100
" -o json
```

**Filter by specific event** (topic0 = keccak256 of event signature):
```bash
dune query run-sql --sql "
SELECT
  block_time,
  tx_hash,
  topic1,  -- indexed param 1 (e.g. 'from' in Transfer)
  topic2,  -- indexed param 2 (e.g. 'to' in Transfer)
  data     -- non-indexed params (e.g. 'value' in Transfer)
FROM <chain>.logs
WHERE contract_address = 0xCONTRACT_ADDRESS
AND topic0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef  -- Transfer(address,address,uint256)
AND block_time >= NOW() - INTERVAL '7' DAY
ORDER BY block_time DESC
LIMIT 100
" -o json
```

> Common topic0 values:
> - `Transfer(address,address,uint256)` = `0xddf252ad...b3ef`
> - `Approval(address,address,uint256)` = `0x8c5be1e5...1a11`
> - `Swap` (Uniswap V2) = `0xd78ad95f...6b87`

**Use decoded event tables when available** (cleaner, named columns):
```bash
# First discover decoded tables for the contract
dune dataset search-by-contract --contract-address 0xCONTRACT_ADDRESS -o json

# The namespace already encodes the chain (e.g. uniswap_v3_base, aave_v3_arbitrum)
dune query run-sql --sql "
SELECT * FROM <namespace>.evt_<EventName>
WHERE contract_address = 0xCONTRACT_ADDRESS
AND evt_block_time >= NOW() - INTERVAL '7' DAY
LIMIT 100
" -o json
```

---

## 5. Labels for an Address

Dune maintains curated label tables that map addresses to human-readable names, categories, and ownership info. This is useful for identifying unknown wallets, contracts, or entities.

**Primary lookup — use `labels.addresses` (consolidated, multi-chain, richest data):**
```bash
dune query run-sql --sql "
SELECT blockchain, address, name, category, label_type, model_name, contributor
FROM labels.addresses
WHERE address = 0xTARGET_ADDRESS
ORDER BY blockchain, category
LIMIT 50
" -o json
```

This single table aggregates labels from all sources: ENS names, DEX personas, NFT activity, CEX deposit addresses, sanctions, and more. It typically returns many rows per address — one per label per chain.

**Reverse lookup — find all addresses for a known entity** (e.g. all Binance wallets):
```bash
dune query run-sql --sql "
SELECT blockchain, address, name, category, label_type
FROM labels.addresses
WHERE LOWER(name) LIKE '%binance%'
ORDER BY blockchain
LIMIT 100
" -o json
```

**If you need ownership/custody details specifically** (who controls an address):
```bash
dune query run-sql --sql "
SELECT address, blockchain, owner_key, custody_owner, account_owner, contract_name
FROM labels.owner_addresses
WHERE address = 0xTARGET_ADDRESS
" -o json
```

**If you need OFAC sanctions check specifically:**
```bash
dune query run-sql --sql "
SELECT address, name, category, label_type
FROM labels.ofac_sanctioned_ethereum
WHERE address = 0xTARGET_ADDRESS
" -o json
```

**What the key tables provide:**
- `labels.addresses` — **Primary table.** All labels in one place: ENS names, behavioral personas (DEX trader, NFT user), protocol affiliations, exchange labels. Columns: `blockchain`, `address`, `name`, `category`, `label_type`, `model_name`, `contributor`
- `labels.owner_addresses` — Ownership/custody data: who custodies/owns an address, contract names, EOA vs factory flags
- `labels.ofac_sanctioned_ethereum` — OFAC-sanctioned addresses (e.g. Tornado Cash contracts)

---

## Error Recovery

| Error | Fix |
|-------|-----|
| `Column cannot be resolved` | Check schema: `dune dataset search --query "<table>" --include-schema -o json` |
| `Type mismatch` | Addresses must use `0x` literal, not string quotes |
| `mismatched input` near `from`/`to` | Must quote reserved words: `"from"`, `"to"` |
| Query timeout / resource limit | Add or tighten `block_time` filter; try `--performance large` |
| `Table does not exist` | Search for correct name: `dune dataset search --query "<keyword>" -o json` |
