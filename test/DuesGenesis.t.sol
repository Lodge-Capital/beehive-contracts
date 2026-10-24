// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveFixture} from "test/helpers/BeehiveFixture.sol";
import {DuesToken} from "contracts/DuesToken.sol";
import {GenesisLaunch} from "contracts/GenesisLaunch.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract DuesGenesisTest is BeehiveFixture {
  function testMaxSupplyAndDisable() public {
    assertEq(dues.maxSupply(), MAX_SUPPLY);
    assertTrue(dues.mintingEnabled());
    dues.mint(alice, 1 ether);
    vm.expectRevert(BeehiveErrors.ExceedsMaxSupply.selector);
    dues.mint(alice, MAX_SUPPLY);
    dues.disableMinting();
    assertFalse(dues.mintingEnabled());
    vm.expectRevert(BeehiveErrors.MintingDisabled.selector);
    dues.mint(alice, 1);
    vm.expectRevert(BeehiveErrors.MintingAlreadyDisabled.selector);
    dues.disableMinting();
  }

  function testOnlyMinterCanMint() public {
    vm.prank(alice);
    vm.expectRevert(BeehiveErrors.Unauthorized.selector);
    dues.mint(alice, 1 ether);
  }

  function testGenesisDistributesAndDisables() public {
    DuesToken fresh = new DuesToken("DUES", "DUES", 18, MAX_SUPPLY, owner);
    genesis = new GenesisLaunch(
      address(fresh), address(quote), owner, uint64(block.timestamp), 30 days, 1_000, 0, 0, 10_000 ether
    );
    fresh.setMinter(address(genesis));
    genesis.setRouter(address(router));
    genesis.setRevenueHub(address(revenue));
    revenue.setApprovedSource(address(genesis), true);

    vm.startPrank(alice);
    quote.approve(address(genesis), 1_000 ether);
    genesis.deposit(1_000 ether);
    vm.stopPrank();
    vm.startPrank(bob);
    quote.approve(address(genesis), 1_000 ether);
    genesis.deposit(1_000 ether);
    vm.stopPrank();

    vm.expectRevert(BeehiveErrors.GenesisOpen.selector);
    genesis.finalize();

    vm.warp(block.timestamp + 30 days);
    genesis.finalize();
    assertFalse(fresh.mintingEnabled());
    assertEq(fresh.totalSupply(), MAX_SUPPLY);

    vm.prank(alice);
    genesis.claim();
    vm.prank(bob);
    genesis.claim();
    assertGt(fresh.balanceOf(alice), 0);
    assertEq(fresh.balanceOf(alice), fresh.balanceOf(bob));
    vm.prank(alice);
    vm.expectRevert(BeehiveErrors.AlreadyClaimed.selector);
    genesis.claim();
  }
}
