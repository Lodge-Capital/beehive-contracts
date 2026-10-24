// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveTypes} from "contracts/BeehiveTypes.sol";

interface IBeehiveLocks {
  function stakeOf(uint256 tokenId) external view returns (BeehiveTypes.Stake memory);
  function weightOf(uint256 tokenId) external view returns (uint256);
  function totalWeight() external view returns (uint256);
  function ownerOf(uint256 tokenId) external view returns (address);
  function creditReward(address token, uint256 amount) external;
  function harvest(uint256 tokenId, address token, address to) external returns (uint256);
}
