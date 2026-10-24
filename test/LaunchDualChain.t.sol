// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockFactory, MockRouter, MockPair} from "test/mocks/MockDex.sol";
import {Create3Factory} from "contracts/Create3Factory.sol";
import {ConfigFactory} from "script/config/ConfigFactory.sol";
import {LaunchCoordinator} from "script/launch/LaunchCoordinator.sol";
import {BeehiveCfg} from "script/config/BeehiveConfig.sol";
import {DuesToken} from "contracts/DuesToken.sol";
import {BeehiveLocks} from "contracts/BeehiveLocks.sol";
import {GenesisLaunch} from "contracts/GenesisLaunch.sol";
import {OmniSettings} from "contracts/omni/OmniSettings.sol";

contract LaunchDualChainTest is Test {
  using LaunchCoordinator for BeehiveCfg;

  function _pairHash() internal pure returns (bytes32) {
    return keccak256(type(MockPair).creationCode);
  }

  function _launch(string memory name, uint256 chainId, bytes32 saltSeed, address quote)
    internal
    returns (BeehiveCfg memory c)
  {
    Create3Factory createx = new Create3Factory();
    MockFactory factory = new MockFactory();
    MockRouter router = new MockRouter(address(factory));
    c = ConfigFactory.live(address(this), address(this), quote, address(router), address(factory), address(createx), _pairHash());
    c = ConfigFactory.withChain(c, name, chainId, "https://example.invalid/rpc");
    c = ConfigFactory.withSalts(c, saltSeed);
    BeehiveCfg memory predicted = LaunchCoordinator.predict(c);
    c = LaunchCoordinator.launchAll(c);
    assertEq(c.addresses.dues, predicted.addresses.dues);
    assertEq(c.addresses.locks, predicted.addresses.locks);
    assertEq(c.addresses.lpPair, predicted.addresses.lpPair);
    assertEq(DuesToken(c.addresses.dues).owner(), address(this));
    assertEq(address(BeehiveLocks(c.addresses.locks).lpToken()), c.addresses.lpPair);
    assertEq(uint256(DuesToken(c.addresses.dues).maxSupply()), 3_333 ether);
  }

  function testLaunchTwoChainConfigs() public {
    MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
    MockERC20 usdt = new MockERC20("Tether", "USDT", 6);

    BeehiveCfg memory base = _launch("base", 8453, keccak256("base-hive"), address(usdc));
    BeehiveCfg memory arb = _launch("arbitrum", 42161, keccak256("arb-hive"), address(usdt));

    assertEq(base.chain.chainId, 8453);
    assertEq(arb.chain.chainId, 42161);
    assertTrue(base.addresses.dues != arb.addresses.dues);
    assertTrue(base.tokens.quote != arb.tokens.quote);
    assertEq(base.tokens.quote, address(usdc));
    assertEq(arb.tokens.quote, address(usdt));

    // Same salts + same launcher + same factory would collide; different seeds do not.
    assertTrue(base.createx.saltDues != arb.createx.saltDues);

    // Omni book is config-driven and disabled by default.
    assertFalse(OmniSettings(base.addresses.omni).enabled());
    assertFalse(OmniSettings(arb.addresses.omni).enabled());

    // Genesis is wired to each chain's quote.
    assertEq(address(GenesisLaunch(base.addresses.genesis).quote()), address(usdc));
    assertEq(address(GenesisLaunch(arb.addresses.genesis).quote()), address(usdt));
  }

  function testPredictedAddressesWrittenAndReusable() public {
    MockERC20 usdc = new MockERC20("USD Coin", "USDC", 18);
    Create3Factory createx = new Create3Factory();
    MockFactory factory = new MockFactory();
    MockRouter router = new MockRouter(address(factory));
    BeehiveCfg memory c = ConfigFactory.live(
      address(this), address(this), address(usdc), address(router), address(factory), address(createx), _pairHash()
    );
    c = ConfigFactory.withChain(c, "base-sepolia", 84532, "https://sepolia.base.org");
    c = LaunchCoordinator.predict(c);
    address dues = c.addresses.dues;
    c = LaunchCoordinator.launchToken(c);
    assertEq(c.addresses.dues, dues);
    assertEq(address(DuesToken(dues).minter()), address(0));
  }
}
