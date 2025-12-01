// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";
import {BeehiveDistributor} from "contracts/BeehiveDistributor.sol";
import {VeArtProxy} from "contracts/VeArtProxy.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract BeehiveEscrowTest is Test {
  MockERC20 token;
  VeArtProxy art;
  BeehiveEscrow escrow;

  function setUp() public {
    token = new MockERC20();
    art = new VeArtProxy();
    escrow = new BeehiveEscrow(address(token), address(art));
    token.mint(address(this), 1_000 ether);
    token.approve(address(escrow), type(uint).max);
  }

  function testEarlyWithdrawPenaltyRoutesToDistributor() public {
    BeehiveDistributor dist = new BeehiveDistributor(address(escrow));
    escrow.setTeam(address(this));
    escrow.setBeehive(address(dist));
    uint tid = escrow.create_lock(100 ether, 4 weeks);
    vm.warp(block.timestamp + 2 weeks);
    uint balBefore = token.balanceOf(address(this));
    escrow.withdraw(tid);
    uint balAfter = token.balanceOf(address(this));
    assertEq(balAfter - balBefore, 50 ether);
    uint week = (block.timestamp / (7 days)) * (7 days);
    assertEq(dist.tokens_per_week(week), 50 ether);
  }

  function testExpiredWithdrawNoPenalty() public {
    uint tid = escrow.create_lock(60 ether, 2 weeks);
    vm.warp(block.timestamp + 3 weeks);
    uint balBefore = token.balanceOf(address(this));
    escrow.withdraw(tid);
    uint balAfter = token.balanceOf(address(this));
    assertEq(balAfter - balBefore, 60 ether);
  }
}