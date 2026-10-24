// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LaunchBase} from "script/launch/LaunchBase.s.sol";
import {ConfigValidator} from "script/config/ConfigValidator.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";

contract ValidateConfig is LaunchBase {
  function run() external view {
    BeehiveCfg memory c = loadCfg();
    bool live = c.createx.factory != address(0) && c.tokens.quote != address(0);
    ConfigValidator.validate(c, live);
  }
}
