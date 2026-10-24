// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ICreateX} from "contracts/interfaces/ICreateX.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

/// @notice CreateX-shaped CREATE3 factory used when the canonical CreateX is not present
///         (local tests). Production configs point `createx.address` at CreateX on that chain.
contract Create3Factory is ICreateX {
  /// @dev 16-byte CREATE3 proxy initcode (solmate / Zefram style).
  bytes private constant PROXY_INITCODE = hex"67363d3d37363d34f03d5260086018f3";
  bytes32 private constant PROXY_CODEHASH = keccak256(hex"67363d3d37363d34f03d5260086018f3");

  event Deployed(address indexed deployer, bytes32 indexed salt, address indexed deployed);

  function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address deployed) {
    bytes32 guarded = _guard(msg.sender, salt);
    bytes memory proxyCode = PROXY_INITCODE;
    address proxy;
    assembly {
      proxy := create2(0, add(proxyCode, 0x20), mload(proxyCode), guarded)
    }
    if (proxy == address(0)) revert BeehiveErrors.DeployFailed();

    (bool ok,) = proxy.call{value: msg.value}(initCode);
    if (!ok) revert BeehiveErrors.InitFailed();

    deployed = _child(proxy);
    if (deployed.code.length == 0) revert BeehiveErrors.InitFailed();
    emit Deployed(msg.sender, salt, deployed);
  }

  function computeCreate3Address(bytes32 salt) external view returns (address) {
    return computeCreate3Address(salt, msg.sender);
  }

  function computeCreate3Address(bytes32 salt, address deployer) public view returns (address) {
    bytes32 guarded = _guard(deployer, salt);
    address proxy = address(
      uint160(
        uint256(
          keccak256(abi.encodePacked(bytes1(0xff), address(this), guarded, PROXY_CODEHASH))
        )
      )
    );
    return _child(proxy);
  }

  function _guard(address deployer, bytes32 salt) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(deployer, salt));
  }

  function _child(address proxy) private pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01))))));
  }
}
