// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {IRewardsDistributor} from "contracts/interfaces/IRewardsDistributor.sol";

contract ClaimRewardsMany is Script {
  function run(address distributor, uint[] memory tokenIds) external {
    vm.startBroadcast();
    IRewardsDistributor(distributor).claim_many(tokenIds);
    vm.stopBroadcast();
  }
}