// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";
import {VeArtProxy} from "contracts/VeArtProxy.sol";

contract DeployEscrow is Script {
  function run(address duesToken, address team) external returns (BeehiveEscrow) {
    vm.startBroadcast();
    VeArtProxy art = new VeArtProxy();
    BeehiveEscrow escrow = new BeehiveEscrow(duesToken, address(art));
    escrow.setTeam(team);
    vm.stopBroadcast();
    return escrow;
  }
}