// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract BeehiveLoansTest is BeehiveFixture {
  function _borrow(uint256 amount) internal returns (uint256 id) {
    uint256 lp = _addLiquidity(alice, 50 ether, 50 ether);
    id = _lock(alice, lp, 180 days);
    vm.prank(lender);
    quote.approve(address(loans), 1_000 ether);
    vm.prank(lender);
    loans.deposit(500 ether);
    vm.startPrank(alice);
    locks.approve(address(loans), id);
    loans.borrow(id, amount);
    vm.stopPrank();
  }

  function testLenderDepositWithdraw() public {
    vm.startPrank(lender);
    quote.approve(address(loans), 100 ether);
    uint256 shares = loans.deposit(100 ether);
    assertEq(shares, 100 ether);
    uint256 out = loans.withdraw(shares);
    assertEq(out, 100 ether);
    vm.stopPrank();
  }

  function testBorrowEscrowsNftAndRepayReturnsIt() public {
    uint256 id = _borrow(20 ether);
    assertEq(locks.ownerOf(id), address(loans));
    (address borrower,,,, bool open) = loans.loans(id);
    assertEq(borrower, alice);
    assertTrue(open);

    vm.warp(block.timestamp + 10 days);
    (uint256 p, uint256 interest) = loans.debtOf(id);
    assertEq(p, 20 ether);
    assertGt(interest, 0);

    vm.startPrank(alice);
    quote.approve(address(loans), p + interest);
    loans.repay(id);
    vm.stopPrank();
    assertEq(locks.ownerOf(id), alice);
  }

  function testExceedsLtvReverts() public {
    uint256 lp = _addLiquidity(alice, 10 ether, 10 ether);
    uint256 id = _lock(alice, lp, 90 days);
    // 10 LP * 2 quote/LP * 35% = 7
    vm.prank(lender);
    quote.approve(address(loans), 100 ether);
    vm.prank(lender);
    loans.deposit(50 ether);
    vm.startPrank(alice);
    locks.approve(address(loans), id);
    vm.expectRevert(BeehiveErrors.ExceedsLTV.selector);
    loans.borrow(id, 20 ether);
    vm.stopPrank();
  }

  function testAuctionSurplusReturnsToBorrower() public {
    uint256 id = _borrow(10 ether);
    oracle.set(4e17);
    assertTrue(loans.isLiquidatable(id));
    loans.startAuction(id);
    uint256 price = loans.currentAuctionPrice(id);
    uint256 bobBefore = quote.balanceOf(alice);
    vm.startPrank(bob);
    quote.approve(address(loans), price);
    loans.bid(id);
    vm.stopPrank();
    assertEq(locks.ownerOf(id), bob);
    assertGt(quote.balanceOf(alice), bobBefore);
  }

  function testCannotWithdrawMoreThanLiquid() public {
    uint256 id = _borrow(30 ether);
    id;
    vm.prank(lender);
    vm.expectRevert(BeehiveErrors.WithdrawLimited.selector);
    loans.withdraw(500 ether);
  }
}
