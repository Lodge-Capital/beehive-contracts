// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
  function transfer(address to, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
  function safeTransfer(IERC20 token, address to, uint256 value) internal {
    require(token.transfer(to, value), "SafeERC20: transfer failed");
  }
  function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
  }
}