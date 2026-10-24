// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ConfigFactory} from "script/config/ConfigFactory.sol";
import {ConfigValidator} from "script/config/ConfigValidator.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract ValidatorHarness {
  function validate(BeehiveCfg memory c, bool live) external pure {
    ConfigValidator.validate(c, live);
  }
}

contract ConfigValidatorTest is Test {
  ValidatorHarness internal harness;

  function setUp() public {
    harness = new ValidatorHarness();
  }

  function _valid() internal view returns (BeehiveCfg memory) {
    return ConfigFactory.live(
      address(this),
      address(this),
      address(0xA11CE),
      address(0xB0B),
      address(0xFAC),
      address(0xC3),
      bytes32(uint256(1))
    );
  }

  function testValidConfigPasses() public view {
    harness.validate(_valid(), true);
  }

  function testRejectsZeroChainId() public {
    BeehiveCfg memory c = _valid();
    c.chain.chainId = 0;
    vm.expectRevert(abi.encodeWithSelector(BeehiveErrors.InvalidConfig.selector, "chain.chainId"));
    harness.validate(c, true);
  }

  function testRejectsBadSplit() public {
    BeehiveCfg memory c = _valid();
    c.fees.stakerShareBps = 1;
    vm.expectRevert(BeehiveErrors.InvalidSplit.selector);
    harness.validate(c, true);
  }

  function testRejectsHaltTrading() public {
    BeehiveCfg memory c = _valid();
    c.haltTrading = true;
    vm.expectRevert(BeehiveErrors.TradingHaltForbidden.selector);
    harness.validate(c, true);
  }

  function testRejectsHighLtv() public {
    BeehiveCfg memory c = _valid();
    c.loans.ltvBps = 6_000;
    vm.expectRevert(abi.encodeWithSelector(BeehiveErrors.InvalidConfig.selector, "loans.ltvBps"));
    harness.validate(c, true);
  }

  function testRejectsMissingQuoteWhenLive() public {
    BeehiveCfg memory c = _valid();
    c.tokens.quote = address(0);
    vm.expectRevert(abi.encodeWithSelector(BeehiveErrors.InvalidConfig.selector, "tokens.quote"));
    harness.validate(c, true);
  }

  function testRejectsLzWithoutEndpoint() public {
    BeehiveCfg memory c = _valid();
    c.layerzero.enabled = true;
    c.layerzero.endpoint = address(0);
    c.layerzero.eid = 30184;
    vm.expectRevert(abi.encodeWithSelector(BeehiveErrors.InvalidConfig.selector, "layerzero.endpoint"));
    harness.validate(c, true);
  }
}
