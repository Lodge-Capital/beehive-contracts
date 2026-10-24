// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";

contract LocksFuzzTest is BeehiveFixture {
  function testFuzzLockUnlockSlash(uint96 duesAmt, uint32 extra) public {
    uint256 amount = bound(uint256(duesAmt), 1 ether, 80 ether);
    uint256 duration = 30 days + (uint256(extra) % (uint256(3 * 365 days) - 30 days));
    dues.mint(alice, amount);
    quote.mint(alice, amount);
    uint256 lp = _addLiquidity(alice, amount, amount);
    uint256 id = _lock(alice, lp, duration);
    uint256 weight = locks.weightOf(id);
    assertGe(weight, lp);
    (uint256 returned,,) = locks.previewUnlock(id);
    vm.prank(alice);
    locks.unlock(id);
    assertEq(pair.balanceOf(alice), returned);
    assertEq(returned + (lp - returned), lp);
  }

  function testFuzzWeightMonotoneInDuration(uint96 amount_, uint32 d1, uint32 d2) public {
    uint256 amount = bound(uint256(amount_), 1, 1000 ether);
    uint256 a = 30 days + (uint256(d1) % (uint256(3 * 365 days) - 30 days));
    uint256 b = 30 days + (uint256(d2) % (uint256(3 * 365 days) - 30 days));
    if (a > b) (a, b) = (b, a);
    uint256 wa = locks.computeWeight(amount, a);
    uint256 wb = locks.computeWeight(amount, b);
    assertLe(wa, wb);
  }
}
