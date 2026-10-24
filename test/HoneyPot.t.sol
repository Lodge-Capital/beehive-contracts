// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";

contract HoneyPotTest is BeehiveFixture {
  function testViewsAndEligibility() public {
    uint256 lp = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 id = _lock(alice, lp, 180 days);
    honey.restartEpoch();
    assertTrue(honey.isEligible(id));
    assertEq(honey.countdown(), 90 days);
    quote.approve(address(revenue), 50 ether);
    revenue.notify(BeehiveTypes.RevenueSource.LodgeFiDeposit, address(quote), 50 ether);
    assertGt(honey.potSize(address(quote)), 0);
  }

  function testFullPeriodStakersClaimProRata() public {
    uint256 lpA = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 lpB = _addLiquidity(bob, 10 ether, 10 ether);
    uint256 idA = _lock(alice, lpA, 180 days);
    uint256 idB = _lock(bob, lpB, 180 days);
    honey.restartEpoch();
    quote.approve(address(revenue), 80 ether);
    revenue.notify(BeehiveTypes.RevenueSource.ProtocolHook, address(quote), 80 ether);

    vm.warp(block.timestamp + 90 days);
    honey.closeEpoch();
    assertTrue(honey.isEligibleForEpoch(idA, 0));
    assertTrue(honey.isEligibleForEpoch(idB, 0));

    uint256 beforeA = quote.balanceOf(alice);
    vm.prank(alice);
    uint256 paidA = honey.claim(idA, 0, address(quote));
    vm.prank(bob);
    uint256 paidB = honey.claim(idB, 0, address(quote));
    assertGt(paidA, 0);
    assertEq(paidA, paidB);
    assertEq(quote.balanceOf(alice) - beforeA, paidA);
  }

  function testMidEpochLockCannotClaim() public {
    uint256 lpA = _addLiquidity(alice, 10 ether, 10 ether);
    _lock(alice, lpA, 180 days);
    honey.restartEpoch();
    vm.warp(block.timestamp + 10 days);
    uint256 lpB = _addLiquidity(bob, 10 ether, 10 ether);
    uint256 idB = _lock(bob, lpB, 180 days);
    assertFalse(honey.isEligible(idB));
    quote.approve(address(revenue), 40 ether);
    revenue.notify(BeehiveTypes.RevenueSource.ProtocolHook, address(quote), 40 ether);
    vm.warp(block.timestamp + 80 days);
    honey.closeEpoch();
    vm.prank(bob);
    vm.expectRevert(BeehiveErrors.NotEligible.selector);
    honey.claim(idB, 0, address(quote));
  }

  function testCannotCloseEarly() public {
    vm.expectRevert(BeehiveErrors.EpochNotEnded.selector);
    honey.closeEpoch();
  }
}
