# Beehive Contracts

Overview
- Time-locked staking of DUES mints a lock NFT.
- Early exits penalize 50% routed via distributor; expired exits return 100%.
- Supports merging locks, voting checkpoints, and delegation.

## Legacy Narrative
The Beehive runs on DUES which is inspired by HEX and has a meximum supply of just 3,333 tokens with the mint function renounced. Genius team, genius tokenomics.

🐝
The Beehive
Honor your stake(s)!

SELF REPAYING LOANS COMING TO EVERY CHAIN.

An Ultra Savings Account For Diamond Hands
Designed for those with unwavering conviction and diamond hands. The Beehive, The Lodge's central pillar, is an ultra-savings account that rewards users who honor their stakes. With the ability to lock DUES tokens for any duration up to 3 years, users can earn higher end-of-term payouts with longer stakes.

The Beehive is the ultimate tool for those who have the discipline and patience to hold onto their investments.

But that's not all The Beehive has to offer.

The protocol also features self-repaying loans, allowing users to borrow against their stake and earn yield that pays back what they borrow.

With the added bonus of daily boosts to APRs through Chainlink VFR, The Lodge provides a unique and rewarding DeFi experience for those who are willing to take the leap. So if you're looking for a DeFi protocol that rewards discipline and offers the opportunity for incredible yield, look no further than The Beehive.

The beehive is a symbol of industry, one where an individual contributes to the betterment of the collective whole without contention.

It's an open secret that time, patience and resolve has been quoted forever as the secret to wealth creation. In that spirit..

Exiting your stake early slashes 50% of your DUES and you willingly forfeit all of your earned BUSD / DUES staking rewards. These rewards are distributed to DUES stakers who are actively honoring their stakes.

Airdrops for DUES Stakers
The Lodge will be releasing many projects over the months/years and every time we launch a new project DUES stakers in the Beehive will receive an airdrop for whatever project we're currently launching.

DUES is the only token that earns rewards from the Beehive.

WHERE DOES THE PROFIT COME FROM?
Beehive profit is generated in 3 or 4 ways:
A 6% sales tax applied to DUES is automatically converted into ETH and adds up in your dashboard which you may collect at any time.

When a user exits their lock before the end date they lose 50% of their staked DUES and 100% of their earned rewards. 

These rewards are distributed to those who did NOT exit their stakes.

Price appreciation: This is a big one.

DUES has a limited supply of only 3,333 and deploying on at least a dozen chains over the next years.

That's 277 DUES per chain, although people will bridge their dues to whichever chain is currently offering the greatest returns.

PRICE DISCOVERY..

Arbitrage: For Arbitrage traders, DUES and LODGE will create a lot of opportunities.


WHEN YOU DEPOSIT DUES INTO THE BEEHIVE
Upon deposit of DUES into The Beehive, you will receive an NFT that has your stake information (how much you deposited, when you deposited it, how long you chose to create your lock, etc). You will need this NFT to redeem your end-of-stake rewards. Consider this NFT your key 🗝️.

MERGING TWO LOCKS
If you have two locks, two NFT's, two keys and want to merge them into one larger stake - not to worry. You may merge stakes/locks at any time. However, the new lock will use the longer time out of the two stakes to prevent fraud.

3,333 $DUES SHARED BETWEEN OVER A DOZEN BLOCKCHAINS?
The Beehive is the 'end of emissions plan' for each tomb deployment. As you provide liquidity for LEVEL and/or LODGE you steadily earn DUES at an exponential rate based on how long and how much liquidity you stake(d). Regular airdrops will also benefit Farmers.

Many DUES will be locked in The Beehive earning ETH + more DUES, lowering the circulating supply even further.


NOTE: EXACTLY 555 DUES ON EACH CHAIN WOULD BE HIGHLY UNLIKELY
SCARCITY
The DUES supply becomes more scarce as diamond-hand investors honor their stakes until the end.

DUES has ZERO team tokens. All 3,333 go to the users who earn/buy them.

WHICH BLOCKCHAINS ARE WE DEPLOYING ON?
Arbitrum

Fantom

ETH

AVAX

POLYGON

OPTIMISM

ZKSYNC

TOMB CHAIN

CRONOS

EVMOS

and many more..

🪙
DUES Supply
Micro Supply Tokenomics at its Finest

MAX DUES: 3,333
INITIAL DUES ~2,000
(The other ~1,000 will slowly reward Farmers in the Lodge)

DEVELOPER PAY: NOTHING / $0 / 0 DUES
No DUES will ever be given to influencers, advertisers, team members or any other 3rd party - only those who buy during presale, earn it in the Farms or buy it from the market.

DUES BELONGS TO THE COMMUNITY
100% of the DUES supply goes directly to those who purchased and/or earned it.

🕖
Earn DUES
Earned DUES should be collected or re-locked - letting price appreciation work its magic.

Three ways to earn DUES:
Provide LEVEL/ETH liquidity (for at least 7 days)

Provide LODGE/ETH liquidity (for at least 7 days)

Create a Beehive stake and earn the DUES slashed from those who exit their stakes early.

After 7 days of Farming, you earn exponentially more DUES every single hour/day/week.

🌟
Rewards
Reward Distribution
BUSD and DUES Reward Distribution Mechanics

How The Beehive Contract Distributes Rewards
The Beehive allocates BUSD and DUES rewards based on the formula: weight = (amount*timelocked)/maxlocktime)At the core of The Lodge lies The Beehive and the Masonry, dual-revolutionary DeFi protocols that reward users for their long-term commitment and strategic choices. The Lodge's sophisticated allocation system distributes BUSD and DUES rewards in a way that is both fair and advantageous to the most dedicated participants. The formula for determining each user's share of rewards is based on a weight calculation that takes into account the amount of DUES that is staked and the length of time it is locked up for.​In other words, the longer you stake your DUES and the more you commit to the protocol, the higher your weight calculation will be, and the larger your share of the rewards. The Beehive's allocation system is carefully designed to incentivize users to think strategically about their investments, and to encourage long-term commitment to the protocol. The more dedicated you are to The Lodge, the more you will be rewarded over time. So if you're looking for a DeFi protocol that values patience, strategic thinking, and long-term commitment, The Lodge and The Beehive are the perfect fit for you. Essentially, the longer you stake and the more DUES you stake the larger your share of the BUSD and DUES distribution.

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