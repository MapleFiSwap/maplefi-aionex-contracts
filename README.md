# MapleFi AIONEX Contracts

**AI-Native DeFi Intelligence & Non-Custodial Execution Infrastructure**

Official smart-contract repository for **MapleFi AIONEX**, deployed across **BNB Chain / BNB Smart Chain (BSC)** and Base mainnet.

MapleFi AIONEX combines deterministic smart-contract execution with real-time DeFi intelligence to help users evaluate liquidity, routes, execution quality and market conditions before signing an onchain transaction.

🌐 **Website:** https://maplefi.xyz
📚 **Docs:** https://docs.maplefi.xyz
𝕏 **Twitter:** https://x.com/MapleFiSwap
💬 **Telegram:** https://t.me/maplefiswap

---

## BNB Smart Chain Mainnet

MapleFi AIONEX is live on **BNB Smart Chain (BSC / BNB Chain)**.

**Network:** BNB Smart Chain
**Chain:** BNB Chain
**Chain ID:** `56`
**Environment:** Mainnet
**Native Asset:** BNB

The BNB deployment uses a modular architecture consisting of the primary **AIONEX BNB Router** and DEX-specific execution adapters.

---

## AIONEX BNB Mainnet Contracts

| Component                             | Contract Address                             |
| ------------------------------------- | -------------------------------------------- |
| **AIONEX BNB Router**                 | `0x13B69E08E67892edBdDce78d7D66B8D109eb2EE3` |
| **AIONEX BNB PancakeSwap V2 Adapter** | `0x2Aa959E6C9e4c4141D0B99A9aF43Dc1337fBec7c` |
| **AIONEX BNB PancakeSwap V3 Adapter** | `0xd640Cb4d780b54d6d9ADe342c70ad0d4316ffE98` |
| **AIONEX BNB Uniswap V3 Adapter**     | `0x6931AeE520e1Ad476e219718b22AAf219137E678` |

### BscScan

**AIONEX BNB Router**
https://bscscan.com/address/0x13B69E08E67892edBdDce78d7D66B8D109eb2EE3

**PancakeSwap V2 Adapter**
https://bscscan.com/address/0x2Aa959E6C9e4c4141D0B99A9aF43Dc1337fBec7c

**PancakeSwap V3 Adapter**
https://bscscan.com/address/0xd640Cb4d780b54d6d9ADe342c70ad0d4316ffE98

**Uniswap V3 Adapter**
https://bscscan.com/address/0x6931AeE520e1Ad476e219718b22AAf219137E678

### Source Directory

`BNBCHAIN MAINNET/AIONEX_BNB_ROUTER`

---

## Architecture

AIONEX separates **intelligence**, **execution coordination** and **DEX-specific connectivity**.

```text
User Wallet
    │
    ▼
MapleFi AIONEX
Intelligence & Decision Layer
    │
    ├── Route Discovery
    ├── Liquidity Intelligence
    ├── Expected Output
    ├── Protected Minimum
    ├── Slippage Analysis
    ├── Price Impact
    ├── Market Health
    └── Execution Quality
    │
    ▼
AIONEX BNB Router
    │
    ├── PancakeSwap V2 Adapter
    ├── PancakeSwap V3 Adapter
    └── Uniswap V3 Adapter
    │
    ▼
Supported DEX Liquidity
    │
    ▼
Wallet-Signed Onchain Execution
```

The modular adapter architecture allows AIONEX to expand supported **BNB Chain DEXs, liquidity venues and DeFi infrastructure** without coupling the complete execution stack to a single protocol.

Third-party DEX routers, pools and liquidity remain external protocol infrastructure and are not MapleFi-owned contracts.

---

## AIONEX Intelligence

AIONEX is designed to evaluate execution conditions before a user signs a transaction.

The intelligence pipeline can analyze:

* supported DEX routes
* liquidity depth
* expected token output
* protected minimum output
* slippage
* price impact
* route competition
* execution conditions
* market-health signals
* execution-quality signals
* transaction state
* explorer-verifiable execution results

AIONEX combines deterministic evidence with an AI interpretation layer to transform fragmented execution data into clearer pre-trade intelligence.

---

## Deterministic + AI Architecture

AIONEX follows a **deterministic-before-generative** architecture.

Smart-contract state, quote calculations, route data and deterministic execution logic remain authoritative.

AI can interpret available evidence and produce contextual intelligence, but AI does not replace deterministic execution.

The architecture is designed so that AI does **not**:

* hold user funds
* access private keys
* sign transactions
* authorize wallet transactions
* independently approve tokens
* replace deterministic onchain pricing
* override smart-contract execution rules

Users retain control of transaction authorization and wallet signatures.

---

## DEX Adapter Infrastructure

### AIONEX BNB Router

The **AIONEX BNB Router** acts as the primary coordination layer for supported AIONEX execution paths on BNB Smart Chain.

`0x13B69E08E67892edBdDce78d7D66B8D109eb2EE3`

---

### PancakeSwap V2 Adapter

Provides the AIONEX integration boundary for supported **PancakeSwap V2** execution paths.

`0x2Aa959E6C9e4c4141D0B99A9aF43Dc1337fBec7c`

---

### PancakeSwap V3 Adapter

Provides the AIONEX integration boundary for supported **PancakeSwap V3** concentrated-liquidity execution paths.

`0xd640Cb4d780b54d6d9ADe342c70ad0d4316ffE98`

---

### Uniswap V3 Adapter

Provides the AIONEX integration boundary for supported **Uniswap V3** execution paths on BNB Smart Chain.

`0x6931AeE520e1Ad476e219718b22AAf219137E678`

---

## Why Modular Adapters?

Liquidity across DeFi is fragmented between protocols, pools, fee tiers and execution models.

AIONEX uses dedicated adapters so new venues can be integrated without redesigning the complete execution architecture.

```text
One Intelligence Layer
        │
        ▼
One Execution Router
        │
        ▼
Multiple Venue Adapters
        │
        ▼
Multiple Liquidity Sources
```

This architecture is designed for progressive expansion across the BNB Chain ecosystem.

---

## Base Mainnet

MapleFi AIONEX also supports **Base mainnet** through dedicated AIONEX routing infrastructure.

### Source Directory

`BASECHAIN MAINNET/AIONEX_BASE_ROUTER`

The multi-network architecture allows AIONEX to maintain a consistent intelligence framework while chain-specific routers and adapters manage network and venue-specific execution.

---

## Non-Custodial Execution

MapleFi AIONEX is designed around wallet-controlled execution.

Users retain control of:

* wallets
* private keys
* token approvals
* transaction authorization
* transaction signatures

AIONEX provides intelligence and execution infrastructure without requiring custody of user private keys.

---

## Core Architecture Principles

### 1. Deterministic Before Generative

Deterministic blockchain and execution evidence remains authoritative.

### 2. Wallet-Controlled Execution

Users authorize and sign their own transactions.

### 3. Multi-Venue Intelligence

AIONEX can evaluate supported liquidity across multiple execution venues rather than depending on a single DEX.

### 4. Modular Integration

DEX-specific adapters allow new liquidity venues and DeFi integrations to be added progressively.

### 5. Verifiable Execution

Executed transactions remain independently verifiable through blockchain explorers.

### 6. Intelligence / Execution Separation

AI interpretation and onchain execution remain separate architectural domains.

---

## BNB Chain Expansion

The AIONEX architecture is designed for continuous integration across the **BNB Chain ecosystem**.

Potential expansion areas include:

* additional BNB Chain DEXs
* additional liquidity sources
* lending protocols
* borrowing markets
* yield infrastructure
* vaults
* token launch infrastructure
* liquidity intelligence
* asset-confidence intelligence
* structured DeFi data
* autonomous agent workflows
* application-facing intelligence APIs

The long-term objective is to transform fragmented DeFi information into reusable intelligence for **users, developers, applications and autonomous agents**.

---

## AIONEX Direction

MapleFi AIONEX is being developed as more than a swap interface.

The architecture is designed to evolve across three layers:

```text
DECISION LAYER
Routes • Liquidity • Risk • Execution Intelligence
                    │
                    ▼
DISTRIBUTION LAYER
Web • APIs • Integrations • DeFi Applications
                    │
                    ▼
AGENT LAYER
Structured Intelligence • Automation • Agent-Ready Execution
```

As network and protocol coverage grows, the same intelligence framework can progressively extend beyond swaps into wider DeFi decision and execution workflows.

---

## Repository Structure

```text
maplefi-aionex-contracts/
│
├── BNBCHAIN MAINNET/
│   └── AIONEX_BNB_ROUTER/
│
└── BASECHAIN MAINNET/
    └── AIONEX_BASE_ROUTER/
```

The repository contains network-specific smart-contract infrastructure supporting MapleFi AIONEX deployments.

---

## Security

Smart contracts and DeFi protocols involve technical, smart-contract, liquidity and market risks.

Users should independently review transaction details before signing and verify contract addresses using official MapleFi channels.

Do not interact with addresses received through unofficial messages, impersonator accounts or unverified sources.

---

## Verify Before Interacting

Always verify that the contract address matches the latest address published through official MapleFi resources.

### Official MapleFi Resources

**Platform**
https://maplefi.xyz

**Documentation**
https://docs.maplefi.xyz

**GitHub**
https://github.com/MapleFiSwap

**X**
https://x.com/MapleFiSwap

**Telegram**
https://t.me/maplefiswap

---

## MapleFi AIONEX

**Observe → Compare → Understand → Execute → Verify**

Building an AI-native intelligence and execution layer for decentralized finance.
