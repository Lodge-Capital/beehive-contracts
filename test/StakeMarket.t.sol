// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract StakeMarketTest is BeehiveFixture {
  function _listed(uint256 ask) internal returns (uint256 id) {
    uint256 lp = _addLiquidity(alice, 10 ether, 10 ether);
    id = _lock(alice, lp, 90 days);
    vm.startPrank(alice);
    locks.approve(address(market), id);
    market.list(id, ask);
    vm.stopPrank();
  }

  function testListBuyCancelAndDiscountView() public {
    uint256 id = _listed(120 ether);
    (uint256 matured, uint256 ask, int256 discount) = market.quoteMaturedValue(id);
    assertEq(ask, 120 ether);
    assertGt(matured, 0);
    assertTrue(discount != 0 || matured == ask);

    vm.prank(alice);
    market.cancel(id);
    assertEq(locks.ownerOf(id), alice);

    vm.startPrank(alice);
    locks.approve(address(market), id);
    market.list(id, 120 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + 1 hours);
    quote.mint(bob, 200 ether);
    vm.startPrank(bob);
    quote.approve(address(market), 120 ether);
    market.buy(id);
    vm.stopPrank();
    assertEq(locks.ownerOf(id), bob);
  }

  function testSelfBuyReverts() public {
    uint256 id = _listed(10 ether);
    vm.warp(block.timestamp + 1 hours);
    vm.startPrank(alice);
    quote.approve(address(market), 10 ether);
    vm.expectRevert(BeehiveErrors.SelfTrade.selector);
    market.buy(id);
    vm.stopPrank();
  }

  function testMinListingTime() public {
    uint256 id = _listed(10 ether);
    vm.startPrank(bob);
    quote.approve(address(market), 10 ether);
    vm.expectRevert(BeehiveErrors.ListingTooFresh.selector);
    market.buy(id);
    vm.stopPrank();
  }
}
