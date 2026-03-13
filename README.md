# Web3 Skills

A collection of skills for Web3 / EVM development and analysis.

## Available Skills

| Skill | Description | Dependencies |
|-------|-------------|--------------|
| [fetch-source](./skills/fetch-source/SKILL.md) | Fetch verified smart contract source code from Sourcify and Etherscan for any EVM-compatible chain | **Optional:** `ETHERSCAN_API_KEY` env var (enables Etherscan fallback) |
| [trace-tx](./skills/trace-tx/SKILL.md) | Fetch full execution traces for EVM transactions via `debug_traceTransaction` — call trees, revert reasons, gas usage, internal transfers. Supports Alchemy (default) or any custom RPC URL | **Optional:** `ALCHEMY_API_KEY` env var (falls back to Alchemy demo key), `RPC_URL` env var (use any custom RPC instead of Alchemy) |
