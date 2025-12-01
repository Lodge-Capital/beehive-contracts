// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";
import {IRewardsDistributor} from "contracts/interfaces/IRewardsDistributor.sol";

contract AdminDashboard is Script {
  function runSetAddresses(address escrow, address team, address distributor) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).setTeam(team);
    BeehiveEscrow(escrow).setBeehive(distributor);
    vm.stopBroadcast();
  }

  function runSetArtProxy(address escrow, address artProxy) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).setArtProxy(artProxy);
    vm.stopBroadcast();
  }

  function runSetVoter(address escrow, address voter) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).setVoter(voter);
    vm.stopBroadcast();
  }

  function runSetLoansAsVoter(address escrow, address loans) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).setVoter(loans);
    vm.stopBroadcast();
  }

  function runCheckpointDistributor(address distributor) external {
    vm.startBroadcast();
    IRewardsDistributor(distributor).checkpoint_total_supply();
    IRewardsDistributor(distributor).checkpoint_token();
    vm.stopBroadcast();
  }

  function runMerge(address escrow, uint fromId, uint toId) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).merge(fromId, toId);
    vm.stopBroadcast();
  }

  function runClaimMany(address distributor, uint[] memory tokenIds) external {
    vm.startBroadcast();
    IRewardsDistributor(distributor).claim_many(tokenIds);
    vm.stopBroadcast();
  }

  function runCreateLock(address escrow, uint amount, uint lockDuration) external returns (uint tokenId) {
    address dues = BeehiveEscrow(escrow).token();
    vm.startBroadcast();
    IERC20(dues).approve(escrow, amount);
    tokenId = BeehiveEscrow(escrow).create_lock(amount, lockDuration);
    vm.stopBroadcast();
    return tokenId;
  }

  function runIncreaseAmount(address escrow, uint tokenId, uint amount) external {
    address dues = BeehiveEscrow(escrow).token();
    vm.startBroadcast();
    IERC20(dues).approve(escrow, amount);
    BeehiveEscrow(escrow).increase_amount(tokenId, amount);
    vm.stopBroadcast();
  }

  function runIncreaseUnlockTime(address escrow, uint tokenId, uint lockDuration) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).increase_unlock_time(tokenId, lockDuration);
    vm.stopBroadcast();
  }

  function runWithdraw(address escrow, uint tokenId) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).withdraw(tokenId);
    vm.stopBroadcast();
  }
}