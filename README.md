<div align="center">

# 🐋 OrcaCoin Staking

**Stake ETH. Earn ORCA. Tokens are minted only when you claim.**

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?style=for-the-badge&logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Foundry-Forge_%7C_Anvil-F05032?style=for-the-badge&logo=ethereum&logoColor=white)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.x-4E5EE4?style=for-the-badge&logo=openzeppelin&logoColor=white)
![Ethereum](https://img.shields.io/badge/Ethereum-EVM_Cancun-3C3C3D?style=for-the-badge&logo=ethereum&logoColor=white)
![ERC-20](https://img.shields.io/badge/ERC--20-OrcaCoin-00C2A8?style=for-the-badge)
![pnpm](https://img.shields.io/badge/pnpm-10-F69220?style=for-the-badge&logo=pnpm&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-31_passing-2EA043?style=for-the-badge&logo=checkmarx&logoColor=white)
![Fuzzing](https://img.shields.io/badge/Fuzz-256_runs-FF6B35?style=for-the-badge)
![Sepolia](https://img.shields.io/badge/Sepolia-Testnet-627EEA?style=for-the-badge&logo=ethereum&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## 📖 Overview

This project is a **staking system built from two smart contracts**:

- **`StakingContract`** accepts native ETH from users and tracks how long each user has staked.
- **`OrcaCoin`** is an ERC-20 reward token. It has **no pre-minted supply**. New tokens are created ("minted") only when a staker claims rewards.

The staking contract is the **only address allowed to mint**. The owner of OrcaCoin decides which contract that is.

## ⚙️ How it works

```
              1 ETH
   User ─────────────────►  StakingContract ───── mint() ─────►  OrcaCoin (ERC-20)
                             • stake                              • mint (staking contract only)
                             • unstake                            • updateStakingContract (owner only)
                             • claimRewards                                 ▲
                             • getRewards                                   │
                                                                          Owner
```

1. **Stake**: a user sends ETH to `stake()`. Their balance and the time are recorded.
2. **Earn**: rewards accrue every second, linearly, at **1 ORCA per 1 ETH per day**.
3. **Claim**: `claimRewards()` makes the staking contract call `OrcaCoin.mint()` and the user receives the earned ORCA.
4. **Unstake**: `unstake(amount)` returns ETH any time. Rewards already earned are kept and stay claimable.

### Reward math

```
rewards = stakedETH × secondsStaked × 1 ORCA / 1 day
```

| Staked | Time | Earned |
|--------|------|--------|
| 1 ETH | 1 day | 1 ORCA |
| 5 ETH | 3 days | 15 ORCA |
| 0.5 ETH | 2 days | 1 ORCA |

Rewards are settled automatically every time a user stakes, unstakes or claims, so topping up or withdrawing never loses earned rewards.

## 📜 Contract reference

### StakingContract

| Function | Description |
|----------|-------------|
| `stake()` payable | Stake the ETH sent with the call. Reverts on zero. |
| `unstake(amount)` | Withdraw part or all of your stake. |
| `claimRewards()` | Mint all earned ORCA to the caller. Reverts with `NoRewards` if nothing earned. |
| `getRewards(user)` view | Settled plus still-accruing rewards right now. |
| `stakedBalance(user)` view | ETH currently staked by a user. |
| `totalStaked()` view | Total ETH staked by everyone. |
| `unclaimedRewards(user)` view | Rewards settled but not yet claimed. |

### OrcaCoin (ORCA, 18 decimals)

| Function | Caller | Description |
|----------|--------|-------------|
| `mint(to, amount)` | Staking contract only | Creates reward tokens. |
| `updateStakingContract(addr)` | Owner only | Sets which contract may mint. The previous one loses rights immediately. |
| Standard ERC-20 | Anyone | `transfer`, `approve`, `balanceOf`, `totalSupply`, ... |

## 🧰 Tech stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Language | ![Solidity](https://img.shields.io/badge/-Solidity_0.8.24-363636?logo=solidity&logoColor=white) | Smart contracts, built-in overflow checks |
| Framework | ![Foundry](https://img.shields.io/badge/-Foundry-F05032?logo=ethereum&logoColor=white) | Compile, test, deploy (`forge`, `anvil`, `cast`) |
| Token standard | ![ERC-20](https://img.shields.io/badge/-ERC--20-00C2A8) | OrcaCoin reward token |
| Libraries | ![OpenZeppelin](https://img.shields.io/badge/-OpenZeppelin_5.x-4E5EE4?logo=openzeppelin&logoColor=white) | `ERC20`, `Ownable`, `ReentrancyGuard` |
| Testing | ![forge-std](https://img.shields.io/badge/-forge--std_1.9.7-FF6B35) | Unit tests, fuzz tests, time travel (`skip`), cheatcodes |
| Package manager | ![pnpm](https://img.shields.io/badge/-pnpm-F69220?logo=pnpm&logoColor=white) | Installs OpenZeppelin, runs scripts |
| Local chain | ![Anvil](https://img.shields.io/badge/-Anvil-3C3C3D?logo=ethereum&logoColor=white) | Local Ethereum node for deployment |
| Testnet | ![Sepolia](https://img.shields.io/badge/-Sepolia-627EEA?logo=ethereum&logoColor=white) | Public test deployment and Etherscan verification |

## 🔒 Security

- **Restricted minting**: only the configured staking contract can mint. Even the owner cannot mint directly.
- **Reentrancy protection**: `nonReentrant` on `stake`, `unstake` and `claimRewards`, and state is updated before ETH is sent.
- **Custom errors** for cheap, clear reverts: `ZeroAmount`, `InsufficientStake`, `NoRewards`, `TransferFailed`, `NotStakingContract`, `ZeroAddress`.
- **Solvency**: a fuzz test checks that the contract's ETH balance always equals the sum of all stakes.

> ⚠️ Unaudited and made for learning. Do not use with real funds as is.

## 🧪 Tests

**31 tests** across two suites:

- `OrcaCoin.t.sol`: metadata, only the staking contract can mint, owner-only updates, old staking contract loses rights, fuzzed access control
- `Staking.t.sol`: stake and unstake flows, exact reward math, top-ups, multiple users, claim rules, reentrancy attack blocked, fuzzed reward formula, round trips and solvency

```bash
pnpm test          # run all tests
pnpm test:gas      # gas report
pnpm coverage      # coverage report
```

## 📁 Project structure

```
orca-staking/
├── src/
│   ├── OrcaCoin.sol            # ERC-20 token with restricted mint
│   └── StakingContract.sol     # ETH staking and reward accounting
├── test/
│   ├── OrcaCoin.t.sol          # token tests
│   └── Staking.t.sol           # staking, rewards, reentrancy, fuzz tests
├── script/
│   └── Deploy.s.sol            # deploys both contracts and links them
├── lib/forge-std/              # vendored test library
├── foundry.toml                # compiler and network config
├── remappings.txt              # import aliases
└── package.json                # pnpm scripts and dependencies
```

## 🚀 Getting started

**Prerequisites**: [Node.js 18+](https://nodejs.org), [pnpm](https://pnpm.io/installation) and [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone https://github.com/swastikjha008-jpg/orca-staking.git
cd orca-staking
pnpm install
pnpm build
pnpm test
```

## 🌐 Deploy

Copy `.env.example` to `.env` and fill it in. Foundry loads `.env` automatically.

```
PRIVATE_KEY=
SEPOLIA_RPC_URL=
ETHERSCAN_API_KEY=
```

**Local**

```bash
pnpm anvil            # terminal 1
pnpm deploy:local     # terminal 2
```

**Sepolia**

```bash
pnpm deploy:sepolia
```

The deploy script:
1. deploys `OrcaCoin` with you as owner
2. deploys `StakingContract` pointing at OrcaCoin
3. calls `updateStakingContract` so the staking contract can mint

> Never commit `.env`. It is already in `.gitignore`.

## 🗺️ Roadmap

- [ ] Owner-adjustable reward rate (settling accruals before the change)
- [ ] Max supply cap on OrcaCoin
- [ ] Lock period or early-unstake penalty
- [ ] Upgradeable version (UUPS proxy)
- [ ] Frontend with wagmi + viem

## 📄 License

[MIT](LICENSE)
