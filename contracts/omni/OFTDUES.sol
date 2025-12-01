// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OFTDUES is OFT {
  constructor(string memory name_, string memory symbol_, address endpoint, address delegate)
    OFT(name_, symbol_, endpoint, delegate)
    Ownable(delegate)
  {}
}