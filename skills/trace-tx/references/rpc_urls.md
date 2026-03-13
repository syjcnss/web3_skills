# Alchemy RPC URLs

Base format: `https://<CHAIN_SLUG>.g.alchemy.com/v2/<API_KEY>`

## Supported chains

| Chain slug            | Network name                |
|-----------------------|-----------------------------|
| `eth-mainnet`         | Ethereum Mainnet            |
| `eth-sepolia`         | Ethereum Sepolia            |
| `arb-mainnet`         | Arbitrum One Mainnet        |
| `arb-sepolia`         | Arbitrum Sepolia            |
| `arbnova-mainnet`     | Arbitrum Nova Mainnet       |
| `base-mainnet`        | Base Mainnet                |
| `base-sepolia`        | Base Sepolia                |
| `opt-mainnet`         | OP Mainnet                  |
| `opt-sepolia`         | OP Mainnet Sepolia          |
| `polygon-mainnet`     | Polygon Mainnet             |
| `polygon-amoy`        | Polygon Amoy (testnet)      |
| `bnb-mainnet`         | BNB Smart Chain Mainnet     |
| `bnb-testnet`         | BNB Smart Chain Testnet     |
| `berachain-mainnet`   | Berachain Mainnet           |
| `celo-mainnet`        | Celo Mainnet                |
| `celo-sepolia`        | Celo Sepolia                |
| `anime-mainnet`       | Anime Mainnet               |
| `apechain-mainnet`    | ApeChain Mainnet            |
| `frax-mainnet`        | Frax Mainnet                |
| `hyperliquid-mainnet` | Hyperliquid Mainnet         |
| `ink-mainnet`         | Ink Mainnet                 |
| `megaeth-testnet`     | MegaETH Testnet             |
| `monad-testnet`       | Monad Testnet               |
| `opbnb-mainnet`       | opBNB Mainnet               |
| `shape-mainnet`       | Shape Mainnet               |
| `soneium-mainnet`     | Soneium Mainnet             |
| `unichain-mainnet`    | Unichain Mainnet            |
| `worldchain-mainnet`  | World Chain Mainnet         |
| `zora-mainnet`        | Zora Mainnet                |
| `zora-sepolia`        | Zora Sepolia                |
| `solana-mainnet`      | Solana Mainnet (non-EVM)    |
| `solana-devnet`       | Solana Devnet (non-EVM)     |

> Note: `debug_traceTransaction` is only available on EVM-compatible chains. Solana uses different APIs.

## Common chain name → slug mapping

When a user mentions a chain by its common name, map it:

| User says              | Use slug              |
|------------------------|-----------------------|
| "Ethereum" / "ETH"     | `eth-mainnet`         |
| "Arbitrum" / "Arb"     | `arb-mainnet`         |
| "Base"                 | `base-mainnet`        |
| "Optimism" / "OP"      | `opt-mainnet`         |
| "Polygon" / "MATIC"    | `polygon-mainnet`     |
| "BSC" / "BNB Chain"    | `bnb-mainnet`         |
| "Sepolia"              | `eth-sepolia`         |
