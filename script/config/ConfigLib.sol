// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";

library ConfigLib {
  using stdJson for string;

  function load(Vm vm, string memory path) internal view returns (BeehiveCfg memory c) {
    string memory json = vm.readFile(path);
    c.chain.name = json.readString(".chain.name");
    c.chain.chainId = json.readUint(".chain.chainId");
    c.chain.rpcUrl = json.readString(".chain.rpcUrl");
    c.chain.explorer = json.readString(".chain.explorer");

    c.createx.factory = json.readAddress(".createx.factory");
    c.createx.launcher = json.readAddress(".createx.launcher");
    c.createx.saltDues = json.readBytes32(".createx.salts.dues");
    c.createx.saltGenesis = json.readBytes32(".createx.salts.genesis");
    c.createx.saltLocks = json.readBytes32(".createx.salts.locks");
    c.createx.saltRevenue = json.readBytes32(".createx.salts.revenue");
    c.createx.saltHoney = json.readBytes32(".createx.salts.honey");
    c.createx.saltMarket = json.readBytes32(".createx.salts.market");
    c.createx.saltLoans = json.readBytes32(".createx.salts.loans");
    c.createx.saltOracle = json.readBytes32(".createx.salts.oracle");
    c.createx.saltBuyback = json.readBytes32(".createx.salts.buyback");
    c.createx.saltTimelock = json.readBytes32(".createx.salts.timelock");
    c.createx.saltOmni = json.readBytes32(".createx.salts.omni");

    c.tokens.duesName = json.readString(".tokens.dues.name");
    c.tokens.duesSymbol = json.readString(".tokens.dues.symbol");
    c.tokens.duesDecimals = uint8(json.readUint(".tokens.dues.decimals"));
    c.tokens.duesMaxSupplyWhole = json.readUint(".tokens.dues.maxSupplyWhole");
    c.tokens.quote = json.readAddress(".tokens.quote.address");
    c.tokens.quoteDecimals = uint8(json.readUint(".tokens.quote.decimals"));
    c.tokens.quoteSymbol = json.readString(".tokens.quote.symbol");

    c.genesis.durationSeconds = uint32(json.readUint(".genesis.durationSeconds"));
    c.genesis.liquiditySeedBps = uint16(json.readUint(".genesis.liquiditySeedBps"));
    c.genesis.timeBonusBps = uint16(json.readUint(".genesis.timeBonusBps"));
    c.genesis.biggerBonusBps = uint16(json.readUint(".genesis.biggerBonusBps"));
    c.genesis.biggerRefWhole = json.readUint(".genesis.biggerRefWhole");
    c.genesis.proceedsToRevenueBps = uint16(json.readUint(".genesis.proceedsToRevenueBps"));

    c.locks.nftName = json.readString(".locks.nftName");
    c.locks.nftSymbol = json.readString(".locks.nftSymbol");
    c.locks.minLockSeconds = uint32(json.readUint(".locks.minLockSeconds"));
    c.locks.maxLockSeconds = uint32(json.readUint(".locks.maxLockSeconds"));
    c.locks.earlyUnlockSlashBps = uint16(json.readUint(".locks.earlyUnlockSlashBps"));
    c.locks.lateGraceSeconds = uint32(json.readUint(".locks.lateGraceSeconds"));
    c.locks.latePenaltyBpsPerDay = uint16(json.readUint(".locks.latePenaltyBpsPerDay"));
    c.locks.maxLatePenaltyBps = uint16(json.readUint(".locks.maxLatePenaltyBps"));
    c.locks.longerBonusBps = uint16(json.readUint(".locks.longerBonusBps"));
    c.locks.biggerBonusBps = uint16(json.readUint(".locks.biggerBonusBps"));
    c.locks.biggerRefWhole = json.readUint(".locks.biggerRefWhole");

    c.fees.marketplaceFeeBps = uint16(json.readUint(".fees.marketplaceFeeBps"));
    c.fees.minListingSeconds = uint32(json.readUint(".fees.minListingSeconds"));
    c.fees.honeyPotShareBps = uint16(json.readUint(".fees.honeyPotShareBps"));
    c.fees.stakerShareBps = uint16(json.readUint(".fees.stakerShareBps"));
    c.fees.buybackShareBps = uint16(json.readUint(".fees.buybackShareBps"));

    c.honeyPot.epochSeconds = uint32(json.readUint(".honeyPot.epochSeconds"));

    c.loans.ltvBps = uint16(json.readUint(".loans.ltvBps"));
    c.loans.liqThresholdBps = uint16(json.readUint(".loans.liqThresholdBps"));
    c.loans.interestAprBps = uint16(json.readUint(".loans.interestAprBps"));
    c.loans.stakerInterestShareBps = uint16(json.readUint(".loans.stakerInterestShareBps"));
    c.loans.auctionDurationSeconds = uint32(json.readUint(".loans.auctionDurationSeconds"));
    c.loans.auctionStartBps = uint16(json.readUint(".loans.auctionStartBps"));

    c.oracle.twapWindowSeconds = uint32(json.readUint(".oracle.twapWindowSeconds"));
    c.oracle.minLiquidity = json.readUint(".oracle.minLiquidity");

    c.dex.router = json.readAddress(".dex.router");
    c.dex.factory = json.readAddress(".dex.factory");
    c.dex.pairInitCodeHash = json.readBytes32(".dex.pairInitCodeHash");

    c.buyback.slippageBps = uint16(json.readUint(".buyback.slippageBps"));

    c.admin.owner = json.readAddress(".admin.owner");
    c.admin.guardian = json.readAddress(".admin.guardian");
    c.admin.treasury = json.readAddress(".admin.treasury");
    c.admin.timelockDelaySeconds = uint32(json.readUint(".admin.timelockDelaySeconds"));
    c.admin.timelockMinDelaySeconds = uint32(json.readUint(".admin.timelockMinDelaySeconds"));
    c.admin.timelockMaxDelaySeconds = uint32(json.readUint(".admin.timelockMaxDelaySeconds"));

    c.layerzero.enabled = json.readBool(".layerzero.enabled");
    c.layerzero.endpoint = json.readAddress(".layerzero.endpoint");
    c.layerzero.eid = uint32(json.readUint(".layerzero.eid"));
    c.layerzero.oft = json.readAddress(".layerzero.oft");
    c.layerzero.onft = json.readAddress(".layerzero.onft");

    c.addresses.dues = json.readAddress(".addresses.dues");
    c.addresses.genesis = json.readAddress(".addresses.genesis");
    c.addresses.locks = json.readAddress(".addresses.locks");
    c.addresses.revenue = json.readAddress(".addresses.revenue");
    c.addresses.honey = json.readAddress(".addresses.honey");
    c.addresses.market = json.readAddress(".addresses.market");
    c.addresses.loans = json.readAddress(".addresses.loans");
    c.addresses.oracle = json.readAddress(".addresses.oracle");
    c.addresses.buyback = json.readAddress(".addresses.buyback");
    c.addresses.timelock = json.readAddress(".addresses.timelock");
    c.addresses.omni = json.readAddress(".addresses.omni");
    c.addresses.lpPair = json.readAddress(".addresses.lpPair");

    c.haltTrading = json.readBool(".haltTrading");
  }

  function writeAddresses(Vm vm, string memory path, BeehiveCfg memory c) internal {
    _writeAddr(vm, path, ".addresses.dues", c.addresses.dues);
    _writeAddr(vm, path, ".addresses.genesis", c.addresses.genesis);
    _writeAddr(vm, path, ".addresses.locks", c.addresses.locks);
    _writeAddr(vm, path, ".addresses.revenue", c.addresses.revenue);
    _writeAddr(vm, path, ".addresses.honey", c.addresses.honey);
    _writeAddr(vm, path, ".addresses.market", c.addresses.market);
    _writeAddr(vm, path, ".addresses.loans", c.addresses.loans);
    _writeAddr(vm, path, ".addresses.oracle", c.addresses.oracle);
    _writeAddr(vm, path, ".addresses.buyback", c.addresses.buyback);
    _writeAddr(vm, path, ".addresses.timelock", c.addresses.timelock);
    _writeAddr(vm, path, ".addresses.omni", c.addresses.omni);
    _writeAddr(vm, path, ".addresses.lpPair", c.addresses.lpPair);
  }

  function _writeAddr(Vm vm, string memory path, string memory key, address value) private {
    vm.writeJson(vm.toString(value), path, key);
  }
}
