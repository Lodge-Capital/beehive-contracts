// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract CreateLock is Script {
  function run(address escrow, uint amount, uint lockDuration) external returns (uint tokenId) {
    address dues = BeehiveEscrow(escrow).token();
    vm.startBroadcast();
    IERC20(dues).approve(escrow, amount);
    tokenId = BeehiveEscrow(escrow).create_lock(amount, lockDuration);
    vm.stopBroadcast();
    return tokenId;
  }
}