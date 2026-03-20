# Web3 Skills

A collection of skills for Web3 / EVM development and analysis.

## Available Skills

| Skill | Description | Dependencies |
|-------|-------------|--------------|
| [fetch-source](./skills/fetch-source/SKILL.md) | Fetch verified smart contract source code from Sourcify and Etherscan for any EVM-compatible chain | **Optional:** `ETHERSCAN_API_KEY` env var (enables Etherscan fallback) |
| [trace-tx](./skills/trace-tx/SKILL.md) | Fetch full execution traces for EVM transactions via `debug_traceTransaction` — call trees, revert reasons, gas usage, internal transfers. Requires an RPC URL (provided in the prompt or constructed from `ALCHEMY_API_KEY`) | **Optional:** `ALCHEMY_API_KEY` env var (used to build Alchemy RPC URL when no URL is provided) |
| [dune2](./skills/dune2/SKILL.md) | Focused Dune CLI skill for on-chain investigation queries: token transfers for an address, contract creation tx, all txs calling a specific function, filtering logs by contract/event, and address label lookups | **Required:** Dune CLI installed and authenticated (`DUNE_API_KEY` env var or `dune auth --api-key <key>`) |
