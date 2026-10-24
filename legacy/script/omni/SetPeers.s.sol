// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {OFTDUES} from "contracts/omni/OFTDUES.sol";
import {ONFTLock} from "contracts/omni/ONFTLock.sol";

contract SetPeers is Script {
  function runSetOFT(address oft, uint32 eid, address peer) external {
    vm.startBroadcast();
    OFTDUES(oft).setPeer(eid, bytes32(uint256(uint160(peer))));
    vm.stopBroadcast();
  }

  function runSetONFT(address onft, uint32 eid, address peer) external {
    vm.startBroadcast();
    ONFTLock(onft).setPeer(eid, bytes32(uint256(uint160(peer))));
    vm.stopBroadcast();
  }
}