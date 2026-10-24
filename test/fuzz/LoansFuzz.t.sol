// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract LoansFuzzTest is BeehiveFixture {
  function testFuzzBorrowRespectsLtv(uint96 lpAmt, uint96 borrowAmt) public {
    uint256 lpIn = bound(uint256(lpAmt), 1 ether, 80 ether);
    dues.mint(alice, lpIn);
    quote.mint(alice, lpIn);
    uint256 lp = _addLiquidity(alice, lpIn, lpIn);
    uint256 id = _lock(alice, lp, 90 days);
    vm.prank(lender);
    quote.approve(address(loans), 10_000 ether);
    vm.prank(lender);
    loans.deposit(5_000 ether);
    uint256 limit = loans.maxBorrow(id);
    uint256 want = bound(uint256(borrowAmt), 1, 5_000 ether);
    vm.startPrank(alice);
    locks.approve(address(loans), id);
    if (want > limit) {
      vm.expectRevert(BeehiveErrors.ExceedsLTV.selector);
      loans.borrow(id, want);
    } else {
      loans.borrow(id, want);
      (uint256 p,) = loans.debtOf(id);
      assertEq(p, want);
      assertLe(p, limit);
    }
    vm.stopPrank();
  }
}
