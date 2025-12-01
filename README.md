# Beehive Contracts

Overview
- Time-locked staking of DUES mints a lock NFT.
- Early exits penalize 50% routed via distributor; expired exits return 100%.
- Supports merging locks, voting checkpoints, and delegation.

## Legacy Narrative
The Beehive runs on DUES which is inspired by HEX and has a meximum supply of just 3,333 tokens with the mint function renounced. Genius team, genius tokenomics.

## Narrative Overview
### Mission
- Reward disciplined, long‑term staking behavior.
- Enable transparent, NFT‑backed positions with clear end‑of‑term outcomes.

### Features
- Time‑locked staking up to 3 years; longer locks earn higher end‑of‑term payouts.
- Self‑repaying loan concept (planned module) using lock NFTs as collateral.
- Optional daily APR boosts via VRF (planned integration).

### Values
- Industry and collective contribution; rewards patience, strategy, and resolve.
- Aligns incentives toward honoring stakes and long‑term participation.

### Early Exit Policy
- Early exit: 50% principal penalty; rewards forfeited; penalty redistributed via distributor.
- Expired exit: 100% principal returned; rewards claimable via distributor.

### Airdrops
- DUES stakers receive airdrops from future Lodge projects on launch.

### Profit Sources (Narrative)
- Sales tax allocation (conceptual) and periodic conversions.
- Early exit penalties redistributed to active stakers.
- Price appreciation and scarcity dynamics.

### Price Discovery & Arbitrage
- Multi‑chain deployment creates opportunities for arbitrage across DUES and related pairs.

### Deposits & NFTs
- On deposit, an NFT is minted containing stake information (amount, start time, chosen lock duration).
- The NFT is required to redeem end‑of‑stake outcomes.

### Merging Locks
- Two positions can be merged into one; the new lock end uses the later of the two end times.

### Cross‑Chain Plan
- Multi‑chain roll‑out over time; users may bridge to chains with higher returns.

### Supply & Tokenomics
- Max DUES: 3,333.
- Initial DUES target ~2,000; remaining emissions reward Farmers.
- No developer pay or team allocation; community‑driven supply.

### Earning DUES
- Provide LEVEL/ETH liquidity (minimum 7 days).
- Provide LODGE/ETH liquidity (minimum 7 days).
- Create a Beehive stake and earn from redistributed penalties.
- Longer participation increases compounding effects over time.

### Rewards Mechanics (Narrative)
- Allocation weight approximates: `weight = (amount * timeLocked) / maxLockTime`.
- Designed to align rewards with commitment duration and stake size.

## Technical Overview
- Contracts live under `contracts/` and are compiled/tested with Foundry.
- Core components:
  - `contracts/BeehiveEscrow.sol`: ve-style escrow that mints an NFT representing a time-locked DUES position; supports create/increase/extend/withdraw, voting checkpoints, and delegation. Early withdrawals return 50% to the user, route 50% to `team` and forfeit rewards.
  - `contracts/BeehiveDistributor.sol`: tracks weekly token distributions and computes claimable amounts per ve position.
  - `contracts/VeArtProxy.sol`: generates on-chain tokenURI metadata.
  - Libraries and interfaces under `contracts/libraries/` and `contracts/interfaces/`.

## Early Exit Policy
- Early withdraw: user receives 50% of the locked principal; the remaining 50% is penalized and routed to `team`. Rewards are forfeited.
- Expired withdraw: user receives 100% of locked principal. If a rewards distributor is set, accrued rewards can be claimed before or at withdraw.
  - Implementation: see `contracts/BeehiveEscrow.sol:922` (withdraw), penalty routing and supply accounting.

## Merging Locks
- Owners can merge two NFTs into one larger stake; the resulting lock end uses the later of the two lock end times.
  - Implementation: `contracts/BeehiveEscrow.sol:1191` (merge).

## Distributor
- Weekly buckets allocated based on ve supply snapshots; users claim per-tokenId.
  - Implementation: `contracts/BeehiveDistributor.sol:194` (claim flow) and `contracts/BeehiveDistributor.sol:57` (checkpoint token).

## Quick Start
- Prereqs: Foundry installed (`forge --version`).
- Build: `cd beehive-contracts && forge build`
- Test: `forge test`
- Remappings: configured in `foundry.toml` for OpenZeppelin and `forge-std`.

## Scripts
- Deploy Escrow: `forge script script/DeployEscrow.s.sol:DeployEscrow --rpc-url <RPC> --broadcast --private-key <KEY> --sig "run(address,address)" <duesToken> <team>`
- Admin Dashboard (multi-action):
  - Set addresses: `--sig "runSetAddresses(address,address,address)" <escrow> <team> <distributor>`
  - Set art proxy: `--sig "runSetArtProxy(address,address)" <escrow> <artProxy>`
  - Set voter: `--sig "runSetVoter(address,address)" <escrow> <voter>`
  - Distributor checkpoints: `--sig "runCheckpointDistributor(address)" <distributor>`
  - Merge locks: `--sig "runMerge(address,uint256,uint256)" <escrow> <fromId> <toId>`
  - Claim many: `--sig "runClaimMany(address,uint256[])" <distributor> "[<id1>,<id2>]"`
  - Create lock: `--sig "runCreateLock(address,uint256,uint256)" <escrow> <amount> <lockDuration>`
  - Increase amount: `--sig "runIncreaseAmount(address,uint256,uint256)" <escrow> <tokenId> <amount>`
  - Increase unlock time: `--sig "runIncreaseUnlockTime(address,uint256,uint256)" <escrow> <tokenId> <lockDuration>`
  - Withdraw: `--sig "runWithdraw(address,uint256)" <escrow> <tokenId>`
- Single-purpose helpers:
- `script/CreateLock.s.sol`, `script/IncreaseAmount.s.sol`, `script/IncreaseUnlockTime.s.sol`, `script/MergeLocks.s.sol`, `script/Withdraw.s.sol`, `script/ClaimRewards.s.sol`, `script/ClaimRewardsMany.s.sol`

### Parameters
- `escrow`: address of `BeehiveEscrow`.
- `distributor`: address of `BeehiveDistributor`.
- `duesToken`: ERC20 token address used for escrow deposits.
- `team`, `voter`, `artProxy`: admin-controlled addresses.
- `amount`: DUES amount (wei) to lock or increase.
- `lockDuration`: seconds to lock or extend (capped at 3 years).
- `tokenId`: veNFT id.

## Examples (Dev Network)
- Assumes an Anvil RPC at `http://localhost:8545` and using the first default account as the broadcaster.
- Example addresses (Anvil):
  - Escrow: `0x1000000000000000000000000000000000000001` (replace with deployed address)
  - Distributor: `0x1000000000000000000000000000000000000002`
  - DUES token: `0x1000000000000000000000000000000000000003`
  - Team: `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`

- Deploy escrow:
  - `forge script script/DeployEscrow.s.sol:DeployEscrow --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "run(address,address)" 0x1000...003 0xf39f...2266`

- Set addresses:
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <TEAM_PK> --sig "runSetAddresses(address,address,address)" 0x1000...001 0xf39f...2266 0x1000...002`

- Create lock (1 DUES for 2 weeks):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runCreateLock(address,uint256,uint256)" 0x1000...001 1000000000000000000 1209600`

- Increase amount (add 0.5 DUES to tokenId 1):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runIncreaseAmount(address,uint256,uint256)" 0x1000...001 1 500000000000000000`

- Increase unlock time (extend by 1 week for tokenId 1):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runIncreaseUnlockTime(address,uint256,uint256)" 0x1000...001 1 604800`

- Merge locks (fromId 1 into toId 2):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runMerge(address,uint256,uint256)" 0x1000...001 1 2`

- Claim rewards (many):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runClaimMany(address,uint256[])" 0x1000...002 "[1,2]"`

- Withdraw (handles early vs expired):
  - `forge script script/AdminDashboard.s.sol:AdminDashboard --rpc-url http://localhost:8545 --broadcast --private-key <ANVIL_PK> --sig "runWithdraw(address,uint256)" 0x1000...001 1`

## Security & Status
- Not audited. Use at your own risk.
- No reliance on `tx.origin` in guards; per-sender-per-block guard only.
- Mixed pragma versions are supported via Foundry auto solc detection.

## Roadmap
- Self-repaying loans against ve positions.
- Chainlink VRF-based daily APR boosts (docs previously used “VFR”; intended “VRF”).
- Expanded distributor logic and cross-chain deployment tooling.