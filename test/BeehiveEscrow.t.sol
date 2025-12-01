// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {BeehiveEscrow} from "contracts/BeehiveEscrow.sol";
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

  function testEarlyWithdrawPenalty() public {
    uint tid = escrow.create_lock(100 ether, 4 weeks);
    escrow.setTeam(address(1));
    vm.warp(block.timestamp + 2 weeks);
    uint balBefore = token.balanceOf(address(this));
    uint teamBefore = token.balanceOf(address(1));
    escrow.withdraw(tid);
    uint balAfter = token.balanceOf(address(this));
    uint teamAfter = token.balanceOf(address(1));
    assertEq(balAfter - balBefore, 50 ether);
    assertEq(teamAfter - teamBefore, 50 ether);
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