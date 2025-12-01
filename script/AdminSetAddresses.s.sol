// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";

contract AdminSetAddresses is Script {
  function run(address escrow, address newTeam, address distributor) external {
    vm.startBroadcast();
    BeehiveEscrow(escrow).setTeam(newTeam);
    BeehiveEscrow(escrow).setBeehive(distributor);
    vm.stopBroadcast();
  }
}