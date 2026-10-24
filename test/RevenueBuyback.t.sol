// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {RevenueHub} from "contracts/RevenueHub.sol";

contract RevenueBuybackTest is BeehiveFixture {
  function testPerSourceEventsAndSplit() public {
    uint256 lp = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 id = _lock(alice, lp, 90 days);
    quote.approve(address(revenue), 100 ether);
    vm.expectEmit(true, true, true, true, address(revenue));
    emit RevenueHub.RevenueInflow(BeehiveTypes.RevenueSource.LodgeFiDeposit, address(quote), 100 ether, address(this));
    revenue.notify(BeehiveTypes.RevenueSource.LodgeFiDeposit, address(quote), 100 ether);
    assertEq(honey.potSize(address(quote)), 25 ether);
    assertGt(locks.pending(id, address(quote)), 0);
    assertEq(quote.balanceOf(address(buyback)), 15 ether);
  }

  function testUnapprovedNotifyReverts() public {
    vm.prank(alice);
    vm.expectRevert(BeehiveErrors.NotApprovedSource.selector);
    revenue.notify(BeehiveTypes.RevenueSource.LodgeFiDeposit, address(quote), 1);
  }

  function testBuybackLocksLiquidity() public {
    _addLiquidity(address(this), 50 ether, 50 ether);
    quote.mint(address(buyback), 20 ether);
    uint256 before = buyback.lockedLiquidity();
    buyback.execute(20 ether);
    assertGt(buyback.lockedLiquidity(), before);
    assertEq(pair.balanceOf(address(buyback)), buyback.lockedLiquidity());
  }

  function testTimelockBoundsSensitiveSetters() public {
    locks.transferOwnership(address(timelock));
    uint256 id =
      timelock.queue(address(locks), abi.encodeWithSelector(locks.setSlashParams.selector, 4_000, 1 days, 40, 4_000));
    vm.expectRevert(BeehiveErrors.TimelockNotReady.selector);
    timelock.execute(id);
    vm.warp(block.timestamp + 2 days);
    timelock.execute(id);
    assertEq(locks.earlySlashBps(), 4_000);
  }
}
