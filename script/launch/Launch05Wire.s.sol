// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LaunchBase} from "script/launch/LaunchBase.s.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {LaunchCoordinator} from "script/launch/LaunchCoordinator.sol";

contract Launch05Wire is LaunchBase {
  function run() external {
    BeehiveCfg memory c = loadCfg();
    vm.startBroadcast();
    c = LaunchCoordinator.wire(c);
    vm.stopBroadcast();
    persist(c);
  }
}
