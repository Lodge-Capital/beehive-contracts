// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract Withdraw is Script {
  function run(address escrow, uint tokenId) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).withdraw(tokenId);
    vm.stopBroadcast();
  }
}