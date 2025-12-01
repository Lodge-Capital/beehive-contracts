// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract IncreaseUnlockTime is Script {
  function run(address escrow, uint tokenId, uint lockDuration) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).increase_unlock_time(tokenId, lockDuration);
    vm.stopBroadcast();
  }
}