// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IHoneyPot {
  function credit(address token, uint256 amount) external;
  function potSize(address token) external view returns (uint256);
  function countdown() external view returns (uint256);
  function isEligible(uint256 tokenId) external view returns (bool);
}
