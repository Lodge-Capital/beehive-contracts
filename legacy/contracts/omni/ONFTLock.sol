// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ONFT721} from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721.sol";

contract ONFTLock is ONFT721 {
  constructor(string memory name_, string memory symbol_, address lzEndpoint, address delegate)
    ONFT721(name_, symbol_, lzEndpoint, delegate)
  {}
}