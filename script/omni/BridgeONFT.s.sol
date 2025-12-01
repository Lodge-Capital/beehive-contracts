// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {ONFTLock} from "contracts/omni/ONFTLock.sol";

contract BridgeONFT is Script {
  function run(address onft, uint32 dstEid, address to, uint256 tokenId, bytes calldata options) external payable {
    vm.startBroadcast();
    ONFTLock(onft).send(dstEid, to, tokenId, options);
    vm.stopBroadcast();
  }
}