# Web3 Skills

A collection of skills for Web3 / EVM development and analysis.

## Available Skills

| Skill | Description | Dependencies |
|-------|-------------|--------------|
| [fetch-source](./skills/fetch-source/SKILL.md) | Fetch verified smart contract source code from Sourcify and Etherscan for any EVM-compatible chain | **Optional:** `ETHERSCAN_API_KEY` env var (enables Etherscan fallback) |
| [trace-tx](./skills/trace-tx/SKILL.md) | Fetch full execution traces for EVM transactions via `debug_traceTransaction` — call trees, revert reasons, gas usage, internal transfers. Requires an RPC URL (provided in the prompt or constructed from `ALCHEMY_API_KEY`) | **Optional:** `ALCHEMY_API_KEY` env var (used to build Alchemy RPC URL when no URL is provided) |
