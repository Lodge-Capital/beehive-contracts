// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract OFTDUES is OFT {
  constructor(string memory name_, string memory symbol_, address lzEndpoint, address delegate)
    OFT(name_, symbol_, lzEndpoint, delegate)
  {}
}