// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVotes {
  function getVotes(address account) external view returns (uint256);
  function getPastVotes(address account, uint256 timestamp) external view returns (uint256);
  function getPastTotalSupply(uint256 timestamp) external view returns (uint256);
}