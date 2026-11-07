# OrcaCoin Staking

Stake native ETH and earn **OrcaCoin (ORCA)**, an ERC-20 token that is **minted on demand** when you claim your rewards.

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?style=for-the-badge&logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Foundry-Forge-F05032?style=for-the-badge&logo=ethereum&logoColor=white)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.x-4E5EE4?style=for-the-badge&logo=openzeppelin&logoColor=white)
![ERC-20](https://img.shields.io/badge/ERC--20-OrcaCoin-00C2A8?style=for-the-badge)
![pnpm](https://img.shields.io/badge/pnpm-10-F69220?style=for-the-badge&logo=pnpm&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-31_passing-2EA043?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

## How it works

```
            1 ETH
  User ───────────────►  StakingContract ───── mint() ─────►  OrcaCoin (ERC-20)
                          stake / unstake                      updateStakingContract()
                          claimRewards / getRewards                    ▲
                                   ▲                                   │
                                   └────────────── Owner ──────────────┘
```

1. A user calls `stake()` with ETH.
2. Rewards accrue every second: **1 ORCA per 1 ETH staked per day** (linear).
3. `claimRewards()` makes the staking contract call `OrcaCoin.mint()`, so tokens are created only when earned.
4. `unstake(amount)` returns ETH at any time. Already-earned rewards are kept and stay claimable.

### StakingContract

| Function | What it does |
|----------|--------------|
| `stake()` payable | Stake the ETH sent. Settles earlier rewards first. |
| `unstake(amount)` | Withdraw part or all of your stake. |
| `claimRewards()` | Mint all earned ORCA to you. Reverts with `NoRewards` if zero. |
| `getRewards(user)` view | Settled + still-accruing rewards right now. |
| `stakedBalance(user)`, `totalStaked()` | Current stake. |

### OrcaCoin

| Function | Who can call | What it does |
|----------|--------------|--------------|
| `mint(to, amount)` | Staking contract only | Creates reward tokens. |
| `updateStakingContract(addr)` | Owner only | Sets which contract may mint. The old one loses rights immediately. |

### Security

- Only the configured staking contract can mint. Even the owner cannot mint directly.
- `nonReentrant` on `stake`, `unstake` and `claimRewards`; state is updated before ETH is sent.
- Custom errors, zero-address and zero-amount checks.
- Fuzz tests check the reward formula and that the contract's ETH always equals total staked.
- Unaudited, for learning. Do not use with real funds as is.

## Tech stack

| Layer | Tools |
|-------|-------|
| Language | Solidity `0.8.24` (EVM `cancun`) |
| Framework | Foundry (forge, anvil, cast) |
| Libraries | OpenZeppelin Contracts `5.x` (ERC20, Ownable, ReentrancyGuard) |
| Testing | forge-std v1.9.7, vendored in `lib/` (unit, fuzz, time travel with `skip`) |
| Package manager | pnpm |

## Project layout

```
src/OrcaCoin.sol            ERC-20 reward token with restricted mint
src/StakingContract.sol     ETH staking + reward accounting
test/OrcaCoin.t.sol         token tests
test/Staking.t.sol          staking, rewards, reentrancy and fuzz tests
script/Deploy.s.sol         deploys both contracts and wires them together
foundry.toml                compiler config
remappings.txt              import aliases (OpenZeppelin, forge-std)
lib/forge-std/              vendored forge-std test library
```

## Getting started

Prerequisites: [Foundry](https://book.getfoundry.sh/getting-started/installation) and [pnpm](https://pnpm.io/installation).

```bash
pnpm install        # installs OpenZeppelin into node_modules (forge-std is vendored in lib/)
pnpm build
pnpm test
```

Other scripts: `pnpm test:gas`, `pnpm coverage`, `pnpm fmt`.

## Deploy

Local:

```bash
pnpm anvil               # terminal 1 (prints test accounts + private keys)
cp .env.example .env     # terminal 2, set PRIVATE_KEY to one of the anvil keys
pnpm deploy:local
```

Sepolia:

```bash
cp .env.example .env     # set PRIVATE_KEY, SEPOLIA_RPC_URL, ETHERSCAN_API_KEY
pnpm deploy:sepolia
```

Foundry loads `.env` automatically (works on Windows, macOS and Linux). `.env` is gitignored, never commit private keys.

The script deploys `OrcaCoin`, deploys `StakingContract`, then calls `updateStakingContract` so the staking contract can mint.

## Ideas to extend

- Owner-adjustable reward rate (settle accruals before changing it)
- Max supply cap on OrcaCoin
- Lock period or early-unstake penalty
- Upgradeable version (UUPS proxy)

## License

MIT
