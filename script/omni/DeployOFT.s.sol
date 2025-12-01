// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {OFTDUES} from "contracts/omni/OFTDUES.sol";

contract DeployOFT is Script {
  function run(string memory name_, string memory symbol_, address endpoint, address delegate) external returns (address) {
    vm.startBroadcast();
    OFTDUES oft = new OFTDUES(name_, symbol_, endpoint, delegate);
    vm.stopBroadcast();
    return address(oft);
  }
}