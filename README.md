# Beehive v2

A HEX-style, revenue-only staking protocol. Users lock **DUES/quote LP** as transferable stake NFTs, earn from real inflows (never inflation), and share a quarterly **Honey Pot**. Loans, a stake marketplace, and a buyback sit on the same config-driven stack.

Launching on any EVM chain (Base first) is a config edit: `beehive.config.json` holds the chain/RPC, token names, supply, every fee/split/timer/LTV/penalty, Honey Pot epoch, quote token, DEX router/factory, oracle settings, admin keys, and LayerZero settings. Contracts do not hardcode chain IDs or addresses.

## Where every dollar of yield comes from

There is **no DUES inflation** after genesis. Stakers are paid only from protocol inflows, all routed through `RevenueHub` with a per-source event:

| Source | What it is | Who pays | Who receives |
| --- | --- | --- | --- |
| Early unlock slash | 50% of LP from a stake unlocked before maturity | The exiting staker | Remaining stakers, Honey Pot, buyback (config split) |
| Late-end penalty | Growing cut of LP if a matured stake sits past the grace window | The late unstaker | Same split |
| Marketplace fee | 7.5% of the quote ask (config) | NFT buyer | Same split |
| Loan interest | APR on escrowed-NFT loans, a config share to stakers | Borrower | Lenders keep the rest; staker share goes through `RevenueHub` |
| LodgeFi deposit hook | Approved-source `notify(LodgeFiDeposit, …)` | LodgeFi / partner | Same split |
| Protocol revenue hook | Approved-source `notify(ProtocolHook, …)` | Any approved module | Same split |
| Genesis proceeds | Quote left after the LP seed when genesis finalizes | Genesis depositors (as the sale) | **Half** (config `proceedsToRevenueBps`, default 50%) through `RevenueHub`; the rest to `admin.treasury` |

Claims (staker rewards and Honey Pot) have **no fee**. Trading is never paused: there is no market halt switch (`haltTrading` in config is rejected by the validator).

### Honey Pot

A configurable share of every inflow accrues for the current epoch (default 90 days). Only stakes that were **active for the entire epoch** (locked at or before epoch start, not unlocked before epoch end) can claim, pro rata by **fixed** lock weight. Views: `potSize`, `countdown`, `isEligible` / `isEligibleForEpoch`. Epochs can be closed by anyone (`closeEpoch`) and also close lazily on credit/claim/unlock, catching up at most four elapsed epochs per call. `restartEpoch` is launch-only and reverts after the first close.

### Marketplace discounts

Listings are in the quote token. `quoteMaturedValue(tokenId)` returns the oracle LP value, the ask, and the discount in bps so a ~40% (or any) discount versus matured value is visible. Anti-wash: no self-buy, and a minimum listing time.

### Loans

The stake NFT is **escrowed** in `BeehiveLoans` for the life of the loan. Borrowers cannot revoke approval to block liquidation. LTV is 30–40% of **TWAP LP value**, not decaying voting power. Lenders `deposit` / `withdraw` shares. Liquidation is a Dutch auction; surplus above debt returns to the borrower.

## Token and locks

- **DUES**: hard cap **3,333**. Genesis (~30 days) mints the cap, seeds DUES/quote LP, then **permanently disables minting**.
- **Locks**: only the DUES/quote LP token. 30 days to 3 years. Each lock is a transferable ERC-721. Longer and larger locks get bonus weight. Weight does **not** decay.

## Config, validator, CreateX

- Schema: `config/beehive.schema.json`
- Examples: `beehive.config.json` (local), `config/beehive.base.example.json` (Base)
- Validator: `script/config/ConfigValidator.sol` — rejects unsafe ranges, share splits ≠ 100%, halt flags, missing live addresses, broken LayerZero peers
- CREATE3: `createx.factory` + per-contract salts. `Launch01Predict` writes predicted addresses back into the config; later stages consume them.

```bash
# validate
forge script script/launch/ValidateConfig.s.sol:ValidateConfig

# staged launch (named launch, not deploy)
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch01Predict.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch02Token.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch03Core.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch04Markets.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch05Wire.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch06Omni.s.sol --rpc-url $RPC --broadcast
BEEHIVE_CONFIG=beehive.config.json forge script script/launch/Launch07Handoff.s.sol --rpc-url $RPC --broadcast
```

Fill `dex.router`, `dex.factory`, `dex.pairInitCodeHash`, `tokens.quote.address`, `createx.factory`, and admin keys in the config for the target chain. LayerZero is optional and config-driven: `OmniSettings` stores endpoint/eid/peers and, when `layerzero.oft` / `layerzero.onft` are set, forwards `setPeer` into those wrappers.

## Build and test

```bash
forge build
forge test
```

Solidity **0.8.26** only. Custom errors, no `assert` access checks. Sensitive setters are bounded and intended to run through `BeehiveTimelock` after handoff.

## Layout

- `contracts/` — DUES, genesis, locks, revenue, Honey Pot, market, loans, TWAP oracle, buyback, timelock, CREATE3 factory, Omni settings
- `script/launch/` — staged launch + validator
- `script/config/` — config struct, JSON loader, factory, validator
- `test/` — unit, fuzz, exploit (slash bypass, liquidation griefing, Honey Pot gaming, wash trades, reentrancy), dual-chain launch
- `legacy/` — Beehive v1 (veNFT + old loans). Not compiled.

## Admin

Owner keeps control. After `Launch07Handoff`, protocol ownership is the timelock. Delay is bounded by config. Guardian can cancel queued calls.

v1 issues this stack removes: borrower approval griefing, decaying-power LTV, liquidator taking the whole NFT at cost, no interest, lenders unable to withdraw `fund()`, no oracle, no timelock, `assert` auth, mixed compiler versions.
