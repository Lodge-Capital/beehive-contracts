// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {ONFTLock} from "contracts/omni/ONFTLock.sol";

contract BridgeONFT is Script {
  function run(address onft, uint dstChainId, address to, uint tokenId, bytes calldata options) external payable {
    vm.startBroadcast();
    ONFTLock(onft).send(dstChainId, to, tokenId, options);
    vm.stopBroadcast();
  }
}