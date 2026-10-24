// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";

contract BeehiveLocksTest is BeehiveFixture {
  function testLockOnlyLpAndWeightBonuses() public {
    uint256 lp = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 shortW = locks.computeWeight(lp, 30 days);
    uint256 longW = locks.computeWeight(lp, 3 * 365 days);
    assertGt(longW, shortW);
    uint256 id = _lock(alice, lp, 90 days);
    assertEq(locks.ownerOf(id), alice);
    assertEq(locks.stakeOf(id).lpAmount, lp);
    assertGt(locks.weightOf(id), lp);
  }

  function testRejectsBadDuration() public {
    uint256 lp = _addLiquidity(alice, 5 ether, 5 ether);
    vm.startPrank(alice);
    pair.approve(address(locks), lp);
    vm.expectRevert(BeehiveErrors.InvalidLockDuration.selector);
    locks.lock(lp, 1 days);
    vm.expectRevert(BeehiveErrors.InvalidLockDuration.selector);
    locks.lock(lp, 10 * 365 days);
    vm.stopPrank();
  }

  function testEarlyUnlockSlashesHalfToStakers() public {
    uint256 lpA = _addLiquidity(alice, 20 ether, 20 ether);
    uint256 lpB = _addLiquidity(bob, 20 ether, 20 ether);
    uint256 idA = _lock(alice, lpA, 180 days);
    uint256 idB = _lock(bob, lpB, 180 days);

    uint256 before = pair.balanceOf(alice);
    vm.prank(alice);
    locks.unlock(idA);
    uint256 returned = pair.balanceOf(alice) - before;
    assertEq(returned, lpA / 2);

    uint256 pendingBob = locks.pending(idB, address(pair));
    // 60% of slash goes to stakers; bob is the only remaining weight.
    assertGt(pendingBob, 0);
    vm.prank(bob);
    uint256 claimed = locks.claim(idB, address(pair));
    assertEq(claimed, pendingBob);
  }

  function testMatureUnlockNoSlashInsideGrace() public {
    uint256 lp = _addLiquidity(alice, 8 ether, 8 ether);
    uint256 id = _lock(alice, lp, 30 days);
    vm.warp(block.timestamp + 30 days + 1);
    uint256 before = pair.balanceOf(alice);
    vm.prank(alice);
    locks.unlock(id);
    assertEq(pair.balanceOf(alice) - before, lp);
  }

  function testLatePenaltyAfterGrace() public {
    uint256 lp = _addLiquidity(alice, 8 ether, 8 ether);
    uint256 id = _lock(alice, lp, 30 days);
    vm.warp(block.timestamp + 30 days + 1 days + 10 days);
    (uint256 returned, uint256 slashed, bool early) = locks.previewUnlock(id);
    assertFalse(early);
    assertGt(slashed, 0);
    assertLt(returned, lp);
    vm.prank(alice);
    locks.unlock(id);
    assertEq(pair.balanceOf(alice), returned);
  }

  function testNftIsTransferable() public {
    uint256 lp = _addLiquidity(alice, 4 ether, 4 ether);
    uint256 id = _lock(alice, lp, 60 days);
    vm.prank(alice);
    locks.transferFrom(alice, bob, id);
    assertEq(locks.ownerOf(id), bob);
  }

  function testNoClaimFee() public {
    uint256 lpA = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 lpB = _addLiquidity(bob, 10 ether, 10 ether);
    _lock(alice, lpA, 90 days);
    uint256 idB = _lock(bob, lpB, 90 days);
    quote.approve(address(revenue), 100 ether);
    revenue.notify(BeehiveTypes.RevenueSource.ProtocolHook, address(quote), 100 ether);
    uint256 pending = locks.pending(idB, address(quote));
    uint256 before = quote.balanceOf(bob);
    vm.prank(bob);
    locks.claim(idB, address(quote));
    assertEq(quote.balanceOf(bob) - before, pending);
  }
}
