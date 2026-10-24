// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUnlock {
  function unlock(uint256 tokenId) external;
  function claim(uint256 tokenId, address token) external;
  function buy(uint256 tokenId) external;
}

contract ReenteringToken is ERC20 {
  address public target;
  uint256 public tokenId;
  bytes4 public selector;
  bool public entered;

  constructor() ERC20("Reenter", "RE") {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function arm(address target_, uint256 tokenId_, bytes4 selector_) external {
    target = target_;
    tokenId = tokenId_;
    selector = selector_;
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    if (!entered && target != address(0)) {
      entered = true;
      if (selector == IUnlock.unlock.selector) {
        IUnlock(target).unlock(tokenId);
      } else if (selector == IUnlock.claim.selector) {
        IUnlock(target).claim(tokenId, address(this));
      } else if (selector == IUnlock.buy.selector) {
        IUnlock(target).buy(tokenId);
      }
    }
    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    if (!entered && target != address(0)) {
      entered = true;
      if (selector == IUnlock.buy.selector) {
        IUnlock(target).buy(tokenId);
      }
    }
    return super.transferFrom(from, to, amount);
  }
}
