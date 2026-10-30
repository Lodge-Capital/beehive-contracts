// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ICreateX} from "contracts/interfaces/ICreateX.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {ConfigValidator} from "script/config/ConfigValidator.sol";
import {DuesToken} from "contracts/DuesToken.sol";
import {GenesisLaunch} from "contracts/GenesisLaunch.sol";
import {BeehiveLocks} from "contracts/BeehiveLocks.sol";
import {RevenueHub} from "contracts/RevenueHub.sol";
import {HoneyPot} from "contracts/HoneyPot.sol";
import {StakeMarket} from "contracts/StakeMarket.sol";
import {BeehiveLoans} from "contracts/BeehiveLoans.sol";
import {TwapOracle} from "contracts/TwapOracle.sol";
import {BuybackEngine} from "contracts/BuybackEngine.sol";
import {BeehiveTimelock} from "contracts/BeehiveTimelock.sol";
import {OmniSettings} from "contracts/omni/OmniSettings.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

/// @notice Stage-able CREATE3 launcher. Must be called by `config.createx.launcher` so salts match.
library LaunchCoordinator {
  event StagePredicted(uint256 indexed chainId, address dues, address locks, address lpPair);
  event StageLaunched(string stage, uint256 indexed chainId);

  function predict(BeehiveCfg memory c) internal view returns (BeehiveCfg memory) {
    ConfigValidator.validate(c, true);
    ICreateX factory = ICreateX(c.createx.factory);
    address d = c.createx.launcher;
    c.addresses.dues = factory.computeCreate3Address(c.createx.saltDues, d);
    c.addresses.genesis = factory.computeCreate3Address(c.createx.saltGenesis, d);
    c.addresses.locks = factory.computeCreate3Address(c.createx.saltLocks, d);
    c.addresses.revenue = factory.computeCreate3Address(c.createx.saltRevenue, d);
    c.addresses.honey = factory.computeCreate3Address(c.createx.saltHoney, d);
    c.addresses.market = factory.computeCreate3Address(c.createx.saltMarket, d);
    c.addresses.loans = factory.computeCreate3Address(c.createx.saltLoans, d);
    c.addresses.oracle = factory.computeCreate3Address(c.createx.saltOracle, d);
    c.addresses.buyback = factory.computeCreate3Address(c.createx.saltBuyback, d);
    c.addresses.timelock = factory.computeCreate3Address(c.createx.saltTimelock, d);
    c.addresses.omni = factory.computeCreate3Address(c.createx.saltOmni, d);
    c.addresses.lpPair = computePair(c.dex.factory, c.addresses.dues, c.tokens.quote, c.dex.pairInitCodeHash);
    return c;
  }

  function computePair(address factory, address tokenA, address tokenB, bytes32 initHash)
    internal
    pure
    returns (address)
  {
    (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    return address(
      uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, keccak256(abi.encodePacked(t0, t1)), initHash))))
    );
  }

  function launchToken(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    ICreateX factory = ICreateX(c.createx.factory);
    uint256 maxSupply = c.tokens.duesMaxSupplyWhole * (10 ** uint256(c.tokens.duesDecimals));
    factory.deployCreate3(
      c.createx.saltDues,
      abi.encodePacked(
        type(DuesToken).creationCode,
        abi.encode(c.tokens.duesName, c.tokens.duesSymbol, c.tokens.duesDecimals, maxSupply, c.admin.owner)
      )
    );
    factory.deployCreate3(
      c.createx.saltGenesis,
      abi.encodePacked(
        type(GenesisLaunch).creationCode,
        abi.encode(
          c.addresses.dues,
          c.tokens.quote,
          c.admin.owner,
          uint64(block.timestamp),
          uint64(c.genesis.durationSeconds),
          c.genesis.liquiditySeedBps,
          c.genesis.timeBonusBps,
          c.genesis.biggerBonusBps,
          c.genesis.biggerRefWhole * (10 ** uint256(c.tokens.quoteDecimals))
        )
      )
    );
    factory.deployCreate3(
      c.createx.saltTimelock,
      abi.encodePacked(
        type(BeehiveTimelock).creationCode,
        abi.encode(
          c.admin.owner,
          c.admin.guardian,
          uint256(c.admin.timelockDelaySeconds),
          uint256(c.admin.timelockMinDelaySeconds),
          uint256(c.admin.timelockMaxDelaySeconds)
        )
      )
    );
    emit StageLaunched("token", c.chain.chainId);
    return c;
  }

  function launchCore(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    ICreateX factory = ICreateX(c.createx.factory);
    factory.deployCreate3(
      c.createx.saltRevenue,
      abi.encodePacked(
        type(RevenueHub).creationCode,
        abi.encode(c.admin.owner, c.fees.honeyPotShareBps, c.fees.stakerShareBps, c.fees.buybackShareBps)
      )
    );
    factory.deployCreate3(
      c.createx.saltHoney,
      abi.encodePacked(
        type(HoneyPot).creationCode,
        abi.encode(c.admin.owner, uint64(c.honeyPot.epochSeconds), uint64(block.timestamp))
      )
    );
    factory.deployCreate3(
      c.createx.saltLocks,
      abi.encodePacked(
        type(BeehiveLocks).creationCode,
        abi.encode(
          c.locks.nftName,
          c.locks.nftSymbol,
          c.addresses.lpPair,
          c.admin.owner,
          c.locks.minLockSeconds,
          c.locks.maxLockSeconds,
          c.locks.earlyUnlockSlashBps,
          c.locks.lateGraceSeconds,
          c.locks.latePenaltyBpsPerDay,
          c.locks.maxLatePenaltyBps,
          c.locks.longerBonusBps,
          c.locks.biggerBonusBps,
          c.locks.biggerRefWhole * (10 ** 18)
        )
      )
    );
    emit StageLaunched("core", c.chain.chainId);
    return c;
  }

  function launchMarkets(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    ICreateX factory = ICreateX(c.createx.factory);
    factory.deployCreate3(
      c.createx.saltOracle,
      abi.encodePacked(
        type(TwapOracle).creationCode,
        abi.encode(
          c.addresses.lpPair,
          c.addresses.dues,
          c.tokens.quote,
          c.admin.owner,
          c.oracle.twapWindowSeconds,
          c.oracle.minLiquidity
        )
      )
    );
    factory.deployCreate3(
      c.createx.saltMarket,
      abi.encodePacked(
        type(StakeMarket).creationCode,
        abi.encode(
          c.addresses.locks, c.tokens.quote, c.admin.owner, c.fees.marketplaceFeeBps, c.fees.minListingSeconds
        )
      )
    );
    factory.deployCreate3(
      c.createx.saltLoans,
      abi.encodePacked(
        type(BeehiveLoans).creationCode,
        abi.encode(
          c.addresses.locks,
          c.tokens.quote,
          c.admin.owner,
          c.loans.ltvBps,
          c.loans.liqThresholdBps,
          c.loans.interestAprBps,
          c.loans.stakerInterestShareBps,
          c.loans.auctionDurationSeconds,
          c.loans.auctionStartBps
        )
      )
    );
    factory.deployCreate3(
      c.createx.saltBuyback,
      abi.encodePacked(
        type(BuybackEngine).creationCode,
        abi.encode(c.addresses.dues, c.tokens.quote, c.admin.owner, c.buyback.slippageBps)
      )
    );
    emit StageLaunched("markets", c.chain.chainId);
    return c;
  }

  function launchOmni(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    ICreateX(c.createx.factory).deployCreate3(
      c.createx.saltOmni,
      abi.encodePacked(
        type(OmniSettings).creationCode,
        abi.encode(c.admin.owner, c.layerzero.endpoint, c.layerzero.eid, c.layerzero.enabled)
      )
    );
    if (c.layerzero.enabled) {
      OmniSettings omni = OmniSettings(c.addresses.omni);
      if (c.layerzero.oft != address(0) || c.layerzero.onft != address(0)) {
        omni.setWrappers(c.layerzero.oft, c.layerzero.onft);
      }
      uint256 n = c.layerzero.peers.length;
      for (uint256 i; i < n; ++i) {
        omni.setPeer(c.layerzero.peers[i].eid, bytes32(uint256(uint160(c.layerzero.peers[i].peer))));
      }
    }
    emit StageLaunched("omni", c.chain.chainId);
    return c;
  }

  function wire(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    DuesToken dues = DuesToken(c.addresses.dues);
    GenesisLaunch genesis = GenesisLaunch(c.addresses.genesis);
    BeehiveLocks locks = BeehiveLocks(c.addresses.locks);
    RevenueHub revenue = RevenueHub(c.addresses.revenue);
    HoneyPot honey = HoneyPot(c.addresses.honey);
    StakeMarket market = StakeMarket(c.addresses.market);
    BeehiveLoans loans = BeehiveLoans(c.addresses.loans);
    BuybackEngine buyback = BuybackEngine(c.addresses.buyback);

    dues.setMinter(c.addresses.genesis);
    genesis.setRouter(c.dex.router);
    genesis.setRevenueHub(c.addresses.revenue);
    if (c.admin.treasury != address(0)) genesis.setTreasury(c.admin.treasury);
    genesis.setProceedsToRevenueBps(c.genesis.proceedsToRevenueBps);
    locks.setModules(c.addresses.revenue, c.addresses.honey);
    revenue.setModules(c.addresses.locks, c.addresses.honey, c.addresses.buyback);
    honey.setLocks(c.addresses.locks);
    honey.setRevenueHub(c.addresses.revenue);
    market.setRevenueHub(c.addresses.revenue);
    market.setOracle(c.addresses.oracle);
    loans.setOracle(c.addresses.oracle);
    loans.setRevenueHub(c.addresses.revenue);
    buyback.setRouter(c.dex.router, c.addresses.lpPair);

    revenue.setApprovedSource(c.addresses.genesis, true);
    revenue.setApprovedSource(c.addresses.locks, true);
    revenue.setApprovedSource(c.addresses.market, true);
    revenue.setApprovedSource(c.addresses.loans, true);

    emit StageLaunched("wire", c.chain.chainId);
    return c;
  }

  function handoffToTimelock(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = _withPredict(c);
    address tl = c.addresses.timelock;
    DuesToken(c.addresses.dues).transferOwnership(tl);
    GenesisLaunch(c.addresses.genesis).transferOwnership(tl);
    BeehiveLocks(c.addresses.locks).transferOwnership(tl);
    RevenueHub(c.addresses.revenue).transferOwnership(tl);
    HoneyPot(c.addresses.honey).transferOwnership(tl);
    StakeMarket(c.addresses.market).transferOwnership(tl);
    BeehiveLoans(c.addresses.loans).transferOwnership(tl);
    TwapOracle(c.addresses.oracle).transferOwnership(tl);
    BuybackEngine(c.addresses.buyback).transferOwnership(tl);
    OmniSettings(c.addresses.omni).transferOwnership(tl);
    emit StageLaunched("handoff", c.chain.chainId);
    return c;
  }

  function launchAll(BeehiveCfg memory c) internal returns (BeehiveCfg memory) {
    c = predict(c);
    c = launchToken(c);
    c = launchCore(c);
    c = launchMarkets(c);
    c = launchOmni(c);
    c = wire(c);
    return c;
  }

  function _withPredict(BeehiveCfg memory c) private view returns (BeehiveCfg memory) {
    if (c.addresses.dues == address(0)) return predict(c);
    ConfigValidator.validate(c, true);
    if (c.addresses.lpPair == address(0)) {
      c.addresses.lpPair = computePair(c.dex.factory, c.addresses.dues, c.tokens.quote, c.dex.pairInitCodeHash);
    }
    return c;
  }
}
