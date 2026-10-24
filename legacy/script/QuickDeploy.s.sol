// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";
import {BeehiveDistributor} from "contracts/BeehiveDistributor.sol";
import {VeArtProxy} from "contracts/VeArtProxy.sol";

contract QuickDeploy is Script {
  struct Output {
    address dues;
    address art;
    address escrow;
    address distributor;
    uint tokenId;
  }

  function run(address team, uint initialMint, uint lockAmount, uint lockDuration) external returns (Output memory out) {
    vm.startBroadcast();
    MockERC20 dues = new MockERC20();
    dues.mint(msg.sender, initialMint);
    VeArtProxy art = new VeArtProxy();
    BeehiveEscrow escrow = new BeehiveEscrow(address(dues), address(art));
    escrow.setTeam(team);
    BeehiveDistributor dist = new BeehiveDistributor(address(escrow));
    escrow.setBeehive(address(dist));
    dues.approve(address(escrow), lockAmount);
    uint tokenId = escrow.create_lock(lockAmount, lockDuration);
    dist.checkpoint_total_supply();
    dist.checkpoint_token();
    vm.stopBroadcast();
    out = Output({dues: address(dues), art: address(art), escrow: address(escrow), distributor: address(dist), tokenId: tokenId});
    return out;
  }
}