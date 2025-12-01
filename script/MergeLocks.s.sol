// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract MergeLocks is Script {
  function run(address escrow, uint fromId, uint toId) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).merge(fromId, toId);
    vm.stopBroadcast();
  }
}