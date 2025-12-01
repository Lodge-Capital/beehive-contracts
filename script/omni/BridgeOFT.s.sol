// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {OFTDUES} from "contracts/omni/OFTDUES.sol";

contract BridgeOFT is Script {
  function run(address oft, uint32 dstEid, address to, uint256 amount, bytes calldata options) external payable {
    vm.startBroadcast();
    OFTDUES(oft).send(dstEid, to, amount, options);
    vm.stopBroadcast();
  }
}