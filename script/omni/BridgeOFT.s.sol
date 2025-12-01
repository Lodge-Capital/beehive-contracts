// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {OFTDUES} from "contracts/omni/OFTDUES.sol";

contract BridgeOFT is Script {
  function run(address oft, uint dstChainId, address to, uint amount, bytes calldata options) external payable {
    vm.startBroadcast();
    OFTDUES(oft).send(dstChainId, to, amount, options);
    vm.stopBroadcast();
  }
}