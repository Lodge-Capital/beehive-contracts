// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {ONFTLock} from "contracts/omni/ONFTLock.sol";

contract DeployONFT is Script {
  function run(string memory name_, string memory symbol_, uint dstChainId, address peer) external returns (address) {
    vm.startBroadcast();
    ONFTLock onft = new ONFTLock(name_, symbol_);
    onft.setPeer(dstChainId, peer);
    vm.stopBroadcast();
    return address(onft);
  }
}