// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

/// @notice Rejects unsafe or chain-hardcoded-looking configuration before any launch stage.
library ConfigValidator {
  uint256 internal constant DAY = 1 days;
  uint256 internal constant YEAR = 365 days;

  function validate(BeehiveCfg memory c, bool requireLiveAddresses) internal pure {
    if (c.haltTrading) revert BeehiveErrors.TradingHaltForbidden();
    if (c.chain.chainId == 0) revert BeehiveErrors.InvalidConfig("chain.chainId");
    if (bytes(c.chain.name).length == 0) revert BeehiveErrors.InvalidConfig("chain.name");
    if (bytes(c.chain.rpcUrl).length == 0) revert BeehiveErrors.InvalidConfig("chain.rpcUrl");

    if (c.createx.factory == address(0) && requireLiveAddresses) {
      revert BeehiveErrors.InvalidConfig("createx.factory");
    }
    if (c.createx.launcher == address(0) && requireLiveAddresses) {
      revert BeehiveErrors.InvalidConfig("createx.launcher");
    }
    _nonzeroSalt(c.createx.saltDues, "createx.saltDues");
    _nonzeroSalt(c.createx.saltGenesis, "createx.saltGenesis");
    _nonzeroSalt(c.createx.saltLocks, "createx.saltLocks");
    _nonzeroSalt(c.createx.saltRevenue, "createx.saltRevenue");
    _nonzeroSalt(c.createx.saltHoney, "createx.saltHoney");
    _nonzeroSalt(c.createx.saltMarket, "createx.saltMarket");
    _nonzeroSalt(c.createx.saltLoans, "createx.saltLoans");
    _nonzeroSalt(c.createx.saltOracle, "createx.saltOracle");
    _nonzeroSalt(c.createx.saltBuyback, "createx.saltBuyback");
    _nonzeroSalt(c.createx.saltTimelock, "createx.saltTimelock");
    _nonzeroSalt(c.createx.saltOmni, "createx.saltOmni");

    if (bytes(c.tokens.duesName).length == 0 || bytes(c.tokens.duesSymbol).length == 0) {
      revert BeehiveErrors.InvalidConfig("tokens.dues");
    }
    if (c.tokens.duesDecimals == 0 || c.tokens.duesDecimals > 18) revert BeehiveErrors.InvalidConfig("tokens.duesDecimals");
    if (c.tokens.quoteDecimals == 0 || c.tokens.quoteDecimals > 18) {
      revert BeehiveErrors.InvalidConfig("tokens.quoteDecimals");
    }
    if (c.tokens.duesMaxSupplyWhole == 0 || c.tokens.duesMaxSupplyWhole > 1_000_000) {
      revert BeehiveErrors.InvalidConfig("tokens.duesMaxSupplyWhole");
    }
    if (requireLiveAddresses && c.tokens.quote == address(0)) revert BeehiveErrors.InvalidConfig("tokens.quote");

    if (c.genesis.durationSeconds < DAY || c.genesis.durationSeconds > 90 * DAY) {
      revert BeehiveErrors.InvalidConfig("genesis.durationSeconds");
    }
    if (c.genesis.liquiditySeedBps > 5_000) revert BeehiveErrors.InvalidConfig("genesis.liquiditySeedBps");
    if (c.genesis.timeBonusBps > 10_000 || c.genesis.biggerBonusBps > 10_000) {
      revert BeehiveErrors.InvalidConfig("genesis.bonus");
    }
    if (c.genesis.biggerRefWhole == 0) revert BeehiveErrors.InvalidConfig("genesis.biggerRefWhole");
    if (c.genesis.proceedsToRevenueBps > 10_000) revert BeehiveErrors.InvalidConfig("genesis.proceedsToRevenueBps");

    if (c.locks.minLockSeconds < DAY) revert BeehiveErrors.InvalidConfig("locks.minLockSeconds");
    if (c.locks.maxLockSeconds > 4 * YEAR) revert BeehiveErrors.InvalidConfig("locks.maxLockSeconds");
    if (c.locks.minLockSeconds >= c.locks.maxLockSeconds) revert BeehiveErrors.InvalidConfig("locks.lockRange");
    if (c.locks.earlyUnlockSlashBps < 1_000 || c.locks.earlyUnlockSlashBps > 8_000) {
      revert BeehiveErrors.InvalidConfig("locks.earlyUnlockSlashBps");
    }
    if (c.locks.latePenaltyBpsPerDay > 500 || c.locks.maxLatePenaltyBps > 8_000) {
      revert BeehiveErrors.InvalidConfig("locks.latePenalty");
    }
    if (c.locks.biggerRefWhole == 0) revert BeehiveErrors.InvalidConfig("locks.biggerRefWhole");
    if (c.locks.longerBonusBps > 50_000 || c.locks.biggerBonusBps > 20_000) {
      revert BeehiveErrors.InvalidConfig("locks.bonus");
    }

    if (uint256(c.fees.honeyPotShareBps) + uint256(c.fees.stakerShareBps) + uint256(c.fees.buybackShareBps) != 10_000) {
      revert BeehiveErrors.InvalidSplit();
    }
    if (c.fees.marketplaceFeeBps > 1_500) revert BeehiveErrors.InvalidConfig("fees.marketplaceFeeBps");
    if (c.fees.minListingSeconds < 60 || c.fees.minListingSeconds > 7 days) {
      revert BeehiveErrors.InvalidConfig("fees.minListingSeconds");
    }

    if (c.honeyPot.epochSeconds < 7 * DAY || c.honeyPot.epochSeconds > 730 * DAY) {
      revert BeehiveErrors.InvalidConfig("honeyPot.epochSeconds");
    }

    if (c.loans.ltvBps < 2_000 || c.loans.ltvBps > 4_000) revert BeehiveErrors.InvalidConfig("loans.ltvBps");
    if (c.loans.liqThresholdBps < c.loans.ltvBps || c.loans.liqThresholdBps > 5_000) {
      revert BeehiveErrors.InvalidConfig("loans.liqThresholdBps");
    }
    if (c.loans.interestAprBps > 5_000) revert BeehiveErrors.InvalidConfig("loans.interestAprBps");
    if (c.loans.stakerInterestShareBps > 10_000) revert BeehiveErrors.InvalidConfig("loans.stakerInterestShareBps");
    if (c.loans.auctionDurationSeconds < 1 hours || c.loans.auctionDurationSeconds > 14 days) {
      revert BeehiveErrors.InvalidConfig("loans.auctionDurationSeconds");
    }
    if (c.loans.auctionStartBps < 10_000 || c.loans.auctionStartBps > 20_000) {
      revert BeehiveErrors.InvalidConfig("loans.auctionStartBps");
    }

    if (c.oracle.twapWindowSeconds < 60 || c.oracle.twapWindowSeconds > 1 days) {
      revert BeehiveErrors.InvalidConfig("oracle.twapWindowSeconds");
    }

    if (requireLiveAddresses) {
      if (c.dex.router == address(0)) revert BeehiveErrors.InvalidConfig("dex.router");
      if (c.dex.factory == address(0)) revert BeehiveErrors.InvalidConfig("dex.factory");
      if (c.dex.pairInitCodeHash == bytes32(0)) revert BeehiveErrors.InvalidConfig("dex.pairInitCodeHash");
    }

    if (c.buyback.slippageBps > 2_000) revert BeehiveErrors.InvalidConfig("buyback.slippageBps");

    if (c.admin.owner == address(0)) revert BeehiveErrors.InvalidConfig("admin.owner");
    if (c.admin.guardian == address(0)) revert BeehiveErrors.InvalidConfig("admin.guardian");
    if (requireLiveAddresses && c.admin.treasury == address(0)) revert BeehiveErrors.InvalidConfig("admin.treasury");
    if (c.admin.timelockMinDelaySeconds < DAY) revert BeehiveErrors.InvalidConfig("admin.timelockMinDelaySeconds");
    if (c.admin.timelockMaxDelaySeconds < c.admin.timelockMinDelaySeconds) {
      revert BeehiveErrors.InvalidConfig("admin.timelockMaxDelaySeconds");
    }
    if (
      c.admin.timelockDelaySeconds < c.admin.timelockMinDelaySeconds
        || c.admin.timelockDelaySeconds > c.admin.timelockMaxDelaySeconds
    ) revert BeehiveErrors.InvalidConfig("admin.timelockDelaySeconds");

    if (c.layerzero.enabled) {
      if (c.layerzero.endpoint == address(0)) revert BeehiveErrors.InvalidConfig("layerzero.endpoint");
      if (c.layerzero.eid == 0) revert BeehiveErrors.InvalidConfig("layerzero.eid");
      uint256 n = c.layerzero.peers.length;
      for (uint256 i; i < n; ++i) {
        if (c.layerzero.peers[i].eid == 0 || c.layerzero.peers[i].eid == c.layerzero.eid) {
          revert BeehiveErrors.InvalidConfig("layerzero.peers.eid");
        }
        if (c.layerzero.peers[i].peer == address(0)) revert BeehiveErrors.InvalidConfig("layerzero.peers.peer");
      }
    }
  }

  function _nonzeroSalt(bytes32 salt, string memory field) private pure {
    if (salt == bytes32(0)) revert BeehiveErrors.InvalidConfig(field);
  }
}
