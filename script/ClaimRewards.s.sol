// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {IRewardsDistributor} from "contracts/interfaces/IRewardsDistributor.sol";

contract ClaimRewards is Script {
  function run(address distributor, uint tokenId) external {
    vm.startBroadcast();
    IRewardsDistributor(distributor).claim(tokenId);
    vm.stopBroadcast();
  }
}