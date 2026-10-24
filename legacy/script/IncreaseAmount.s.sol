// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract IncreaseAmount is Script {
  function run(address escrow, uint tokenId, uint amount) external {
    address dues = BeehiveEscrow(escrow).token();
    vm.startBroadcast();
    IERC20(dues).approve(escrow, amount);
    BeehiveEscrow(escrow).increase_amount(tokenId, amount);
    vm.stopBroadcast();
  }
}