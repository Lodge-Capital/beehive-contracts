// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice CreateX-shaped CREATE3 factory. Address comes from config, never hardcoded.
interface ICreateX {
  function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address);
  function computeCreate3Address(bytes32 salt) external view returns (address);
  function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}
