// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    return a + b;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SafeMath: subtraction overflow");
    return a - b;
  }
}