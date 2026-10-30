// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveCfg} from "script/config/BeehiveConfig.sol";

library ConfigFactory {
  function baseTemplate() internal pure returns (BeehiveCfg memory c) {
    c.chain.name = "anvil";
    c.chain.chainId = 31337;
    c.chain.rpcUrl = "http://127.0.0.1:8545";
    c.chain.explorer = "";

    c.createx.saltDues = keccak256("beehive.v2.dues");
    c.createx.saltGenesis = keccak256("beehive.v2.genesis");
    c.createx.saltLocks = keccak256("beehive.v2.locks");
    c.createx.saltRevenue = keccak256("beehive.v2.revenue");
    c.createx.saltHoney = keccak256("beehive.v2.honey");
    c.createx.saltMarket = keccak256("beehive.v2.market");
    c.createx.saltLoans = keccak256("beehive.v2.loans");
    c.createx.saltOracle = keccak256("beehive.v2.oracle");
    c.createx.saltBuyback = keccak256("beehive.v2.buyback");
    c.createx.saltTimelock = keccak256("beehive.v2.timelock");
    c.createx.saltOmni = keccak256("beehive.v2.omni");

    c.tokens.duesName = "DUES";
    c.tokens.duesSymbol = "DUES";
    c.tokens.duesDecimals = 18;
    c.tokens.duesMaxSupplyWhole = 3_333;
    c.tokens.quoteDecimals = 18;
    c.tokens.quoteSymbol = "USDC";

    c.genesis.durationSeconds = 30 days;
    c.genesis.liquiditySeedBps = 1_000;
    c.genesis.timeBonusBps = 2_000;
    c.genesis.biggerBonusBps = 1_000;
    c.genesis.biggerRefWhole = 10_000;
    c.genesis.proceedsToRevenueBps = 5_000;

    c.locks.nftName = "Beehive Stake";
    c.locks.nftSymbol = "HIVE";
    c.locks.minLockSeconds = 30 days;
    c.locks.maxLockSeconds = 3 * 365 days;
    c.locks.earlyUnlockSlashBps = 5_000;
    c.locks.lateGraceSeconds = 1 days;
    c.locks.latePenaltyBpsPerDay = 50;
    c.locks.maxLatePenaltyBps = 5_000;
    c.locks.longerBonusBps = 20_000;
    c.locks.biggerBonusBps = 10_000;
    c.locks.biggerRefWhole = 10;

    c.fees.marketplaceFeeBps = 750;
    c.fees.minListingSeconds = 1 hours;
    c.fees.honeyPotShareBps = 2_500;
    c.fees.stakerShareBps = 6_000;
    c.fees.buybackShareBps = 1_500;

    c.honeyPot.epochSeconds = 90 days;

    c.loans.ltvBps = 3_500;
    c.loans.liqThresholdBps = 4_000;
    c.loans.interestAprBps = 1_200;
    c.loans.stakerInterestShareBps = 4_000;
    c.loans.auctionDurationSeconds = 1 days;
    c.loans.auctionStartBps = 10_000;

    c.oracle.twapWindowSeconds = 30 minutes;
    c.oracle.minLiquidity = 1_000;

    c.buyback.slippageBps = 300;

    c.admin.timelockDelaySeconds = 2 days;
    c.admin.timelockMinDelaySeconds = 1 days;
    c.admin.timelockMaxDelaySeconds = 30 days;

    c.layerzero.enabled = false;
    c.haltTrading = false;
  }

  function live(address owner, address guardian, address quote, address router, address factory, address createx, bytes32 pairInitHash)
    internal
    view
    returns (BeehiveCfg memory c)
  {
    c = baseTemplate();
    c.createx.factory = createx;
    c.createx.launcher = owner;
    c.tokens.quote = quote;
    c.dex.router = router;
    c.dex.factory = factory;
    c.dex.pairInitCodeHash = pairInitHash;
    c.admin.owner = owner;
    c.admin.guardian = guardian;
    c.admin.treasury = owner;
  }

  function withChain(BeehiveCfg memory c, string memory name, uint256 chainId, string memory rpc)
    internal
    pure
    returns (BeehiveCfg memory)
  {
    c.chain.name = name;
    c.chain.chainId = chainId;
    c.chain.rpcUrl = rpc;
    return c;
  }

  function withSalts(BeehiveCfg memory c, bytes32 seed) internal pure returns (BeehiveCfg memory) {
    c.createx.saltDues = keccak256(abi.encodePacked(seed, "dues"));
    c.createx.saltGenesis = keccak256(abi.encodePacked(seed, "genesis"));
    c.createx.saltLocks = keccak256(abi.encodePacked(seed, "locks"));
    c.createx.saltRevenue = keccak256(abi.encodePacked(seed, "revenue"));
    c.createx.saltHoney = keccak256(abi.encodePacked(seed, "honey"));
    c.createx.saltMarket = keccak256(abi.encodePacked(seed, "market"));
    c.createx.saltLoans = keccak256(abi.encodePacked(seed, "loans"));
    c.createx.saltOracle = keccak256(abi.encodePacked(seed, "oracle"));
    c.createx.saltBuyback = keccak256(abi.encodePacked(seed, "buyback"));
    c.createx.saltTimelock = keccak256(abi.encodePacked(seed, "timelock"));
    c.createx.saltOmni = keccak256(abi.encodePacked(seed, "omni"));
    return c;
  }
}
