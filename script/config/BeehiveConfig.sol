// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

struct ChainCfg {
  string name;
  uint256 chainId;
  string rpcUrl;
  string explorer;
}

struct CreatexCfg {
  address factory;
  address launcher;
  bytes32 saltDues;
  bytes32 saltGenesis;
  bytes32 saltLocks;
  bytes32 saltRevenue;
  bytes32 saltHoney;
  bytes32 saltMarket;
  bytes32 saltLoans;
  bytes32 saltOracle;
  bytes32 saltBuyback;
  bytes32 saltTimelock;
  bytes32 saltOmni;
}

struct TokenCfg {
  string duesName;
  string duesSymbol;
  uint8 duesDecimals;
  uint256 duesMaxSupplyWhole;
  address quote;
  uint8 quoteDecimals;
  string quoteSymbol;
}

struct GenesisCfg {
  uint32 durationSeconds;
  uint16 liquiditySeedBps;
  uint16 timeBonusBps;
  uint16 biggerBonusBps;
  uint256 biggerRefWhole;
}

struct LockCfg {
  string nftName;
  string nftSymbol;
  uint32 minLockSeconds;
  uint32 maxLockSeconds;
  uint16 earlyUnlockSlashBps;
  uint32 lateGraceSeconds;
  uint16 latePenaltyBpsPerDay;
  uint16 maxLatePenaltyBps;
  uint16 longerBonusBps;
  uint16 biggerBonusBps;
  uint256 biggerRefWhole;
}

struct FeeCfg {
  uint16 marketplaceFeeBps;
  uint32 minListingSeconds;
  uint16 honeyPotShareBps;
  uint16 stakerShareBps;
  uint16 buybackShareBps;
}

struct HoneyCfg {
  uint32 epochSeconds;
}

struct LoanCfg {
  uint16 ltvBps;
  uint16 liqThresholdBps;
  uint16 interestAprBps;
  uint16 stakerInterestShareBps;
  uint32 auctionDurationSeconds;
  uint16 auctionStartBps;
}

struct OracleCfg {
  uint32 twapWindowSeconds;
  uint256 minLiquidity;
}

struct DexCfg {
  address router;
  address factory;
  bytes32 pairInitCodeHash;
}

struct BuybackCfg {
  uint16 slippageBps;
}

struct AdminCfg {
  address owner;
  address guardian;
  uint32 timelockDelaySeconds;
  uint32 timelockMinDelaySeconds;
  uint32 timelockMaxDelaySeconds;
}

struct LzPeerCfg {
  uint32 eid;
  address peer;
}

struct LayerZeroCfg {
  bool enabled;
  address endpoint;
  uint32 eid;
  LzPeerCfg[] peers;
}

struct AddressBook {
  address dues;
  address genesis;
  address locks;
  address revenue;
  address honey;
  address market;
  address loans;
  address oracle;
  address buyback;
  address timelock;
  address omni;
  address lpPair;
}

struct BeehiveCfg {
  ChainCfg chain;
  CreatexCfg createx;
  TokenCfg tokens;
  GenesisCfg genesis;
  LockCfg locks;
  FeeCfg fees;
  HoneyCfg honeyPot;
  LoanCfg loans;
  OracleCfg oracle;
  DexCfg dex;
  BuybackCfg buyback;
  AdminCfg admin;
  LayerZeroCfg layerzero;
  AddressBook addresses;
  bool haltTrading;
}
