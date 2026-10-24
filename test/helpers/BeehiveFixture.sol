// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockFactory, MockRouter, MockPair} from "test/mocks/MockDex.sol";
import {MockOracle} from "test/mocks/MockOracle.sol";
import {DuesToken} from "contracts/DuesToken.sol";
import {GenesisLaunch} from "contracts/GenesisLaunch.sol";
import {BeehiveLocks} from "contracts/BeehiveLocks.sol";
import {RevenueHub} from "contracts/RevenueHub.sol";
import {HoneyPot} from "contracts/HoneyPot.sol";
import {StakeMarket} from "contracts/StakeMarket.sol";
import {BeehiveLoans} from "contracts/BeehiveLoans.sol";
import {BuybackEngine} from "contracts/BuybackEngine.sol";
import {BeehiveTimelock} from "contracts/BeehiveTimelock.sol";
import {TwapOracle} from "contracts/TwapOracle.sol";

contract BeehiveFixture is Test {
  MockERC20 internal quote;
  DuesToken internal dues;
  MockFactory internal factory;
  MockRouter internal router;
  MockPair internal pair;
  MockOracle internal oracle;

  GenesisLaunch internal genesis;
  BeehiveLocks internal locks;
  RevenueHub internal revenue;
  HoneyPot internal honey;
  StakeMarket internal market;
  BeehiveLoans internal loans;
  BuybackEngine internal buyback;
  BeehiveTimelock internal timelock;

  address internal owner = address(this);
  address internal alice = makeAddr("alice");
  address internal bob = makeAddr("bob");
  address internal lender = makeAddr("lender");

  uint256 internal constant MAX_SUPPLY = 3_333 ether;

  function setUp() public virtual {
    quote = new MockERC20("USD Coin", "USDC", 18);
    dues = new DuesToken("DUES", "DUES", 18, MAX_SUPPLY, owner);
    factory = new MockFactory();
    router = new MockRouter(address(factory));
    oracle = new MockOracle();

    revenue = new RevenueHub(owner, 2_500, 6_000, 1_500);
    honey = new HoneyPot(owner, 90 days, uint64(block.timestamp));
    genesis = new GenesisLaunch(
      address(dues), address(quote), owner, uint64(block.timestamp), 30 days, 1_000, 2_000, 1_000, 10_000 ether
    );
    buyback = new BuybackEngine(address(dues), address(quote), owner, 300);
    timelock = new BeehiveTimelock(owner, owner, 2 days, 1 days, 30 days);

    dues.setMinter(address(this));
    dues.mint(address(this), 1_000 ether);
    address predictedPair = factory.createPair(address(dues), address(quote));
    pair = MockPair(predictedPair);

    locks = new BeehiveLocks(
      "Beehive Stake",
      "HIVE",
      predictedPair,
      owner,
      30 days,
      uint32(3 * 365 days),
      5_000,
      1 days,
      50,
      5_000,
      20_000,
      10_000,
      10 ether
    );
    market = new StakeMarket(address(locks), address(quote), owner, 750, 1 hours);
    loans = new BeehiveLoans(address(locks), address(quote), owner, 3_500, 4_000, 1_200, 4_000, 1 days, 10_000);

    revenue.setModules(address(locks), address(honey), address(buyback));
    locks.setModules(address(revenue), address(honey));
    honey.setLocks(address(locks));
    honey.setRevenueHub(address(revenue));
    genesis.setRouter(address(router));
    genesis.setRevenueHub(address(revenue));
    market.setRevenueHub(address(revenue));
    market.setOracle(address(oracle));
    loans.setOracle(address(oracle));
    loans.setRevenueHub(address(revenue));
    buyback.setRouter(address(router), address(pair));
    revenue.setApprovedSource(address(genesis), true);
    revenue.setApprovedSource(address(locks), true);
    revenue.setApprovedSource(address(market), true);
    revenue.setApprovedSource(address(loans), true);
    revenue.setApprovedSource(address(this), true);

    quote.mint(address(this), 1_000_000 ether);
    quote.mint(alice, 1_000_000 ether);
    quote.mint(bob, 1_000_000 ether);
    quote.mint(lender, 1_000_000 ether);
    dues.mint(alice, 200 ether);
    dues.mint(bob, 200 ether);
  }

  function _addLiquidity(address who, uint256 duesAmt, uint256 quoteAmt) internal returns (uint256 lp) {
    vm.startPrank(who);
    dues.approve(address(router), duesAmt);
    quote.approve(address(router), quoteAmt);
    (,, lp) = router.addLiquidity(address(dues), address(quote), duesAmt, quoteAmt, 0, 0, who, block.timestamp);
    vm.stopPrank();
  }

  function _lock(address who, uint256 lpAmt, uint256 duration) internal returns (uint256 id) {
    vm.startPrank(who);
    pair.approve(address(locks), lpAmt);
    id = locks.lock(lpAmt, duration);
    vm.stopPrank();
  }
}
