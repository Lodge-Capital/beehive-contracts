// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {ConfigLib} from "script/config/ConfigLib.sol";
import {LaunchCoordinator} from "script/launch/LaunchCoordinator.sol";

abstract contract LaunchBase is Script {
  using LaunchCoordinator for BeehiveCfg;

  function configPath() public view returns (string memory) {
    try vm.envString("BEEHIVE_CONFIG") returns (string memory p) {
      return p;
    } catch {
      return "beehive.config.json";
    }
  }

  function loadCfg() internal view returns (BeehiveCfg memory) {
    return ConfigLib.load(vm, configPath());
  }

  function persist(BeehiveCfg memory c) internal {
    ConfigLib.writeAddresses(vm, configPath(), c);
  }
}
