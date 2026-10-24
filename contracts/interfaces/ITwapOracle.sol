// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITwapOracle {
  function consultLpValue(uint256 lpAmount) external view returns (uint256 quoteValue);
  function ready() external view returns (bool);
  function update() external;
}
