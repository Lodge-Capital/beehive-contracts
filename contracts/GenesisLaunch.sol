// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DuesToken} from "contracts/DuesToken.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {IRevenueHub} from "contracts/interfaces/IRevenueHub.sol";
import {IUniswapV2Router02} from "contracts/interfaces/IUniswapV2Router02.sol";

/// @notice ~30-day share-based genesis. Mints the full DUES cap, seeds LP, then disables minting.
contract GenesisLaunch is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  DuesToken public immutable dues;
  IERC20 public immutable quote;
  IUniswapV2Router02 public router;
  IRevenueHub public revenueHub;

  uint64 public immutable start;
  uint64 public immutable duration;
  uint16 public immutable seedBps;
  uint16 public immutable timeBonusBps;
  uint16 public immutable biggerBonusBps;
  uint256 public immutable biggerRef;

  uint256 public totalShares;
  uint256 public totalQuote;
  uint256 public claimableDues;
  bool public finalized;
  address public lpToken;
  uint256 public seededLp;

  mapping(address => uint256) public sharesOf;
  mapping(address => bool) public claimed;

  event Deposited(address indexed user, uint256 quoteAmount, uint256 shares);
  event Finalized(uint256 minted, uint256 seededDues, uint256 seededQuote, uint256 leftoverQuote);
  event Claimed(address indexed user, uint256 amount);

  constructor(
    address dues_,
    address quote_,
    address owner_,
    uint64 start_,
    uint64 duration_,
    uint16 seedBps_,
    uint16 timeBonusBps_,
    uint16 biggerBonusBps_,
    uint256 biggerRef_
  ) Ownable(owner_) {
    if (dues_ == address(0) || quote_ == address(0) || owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (duration_ == 0 || seedBps_ > 5_000 || biggerRef_ == 0) revert BeehiveErrors.OutOfBounds();
    dues = DuesToken(dues_);
    quote = IERC20(quote_);
    start = start_;
    duration = duration_;
    seedBps = seedBps_;
    timeBonusBps = timeBonusBps_;
    biggerBonusBps = biggerBonusBps_;
    biggerRef = biggerRef_;
  }

  function setRouter(address router_) external onlyOwner {
    if (router_ == address(0)) revert BeehiveErrors.ZeroAddress();
    router = IUniswapV2Router02(router_);
  }

  function setRevenueHub(address hub_) external onlyOwner {
    if (hub_ == address(0)) revert BeehiveErrors.ZeroAddress();
    revenueHub = IRevenueHub(hub_);
  }

  function deadline() public view returns (uint64) {
    return start + duration;
  }

  function remaining() public view returns (uint256) {
    uint64 end_ = deadline();
    if (block.timestamp >= end_) return 0;
    return uint256(end_ - uint64(block.timestamp));
  }

  function previewShares(uint256 amount) public view returns (uint256) {
    uint256 timeBonus = duration == 0 ? 0 : (remaining() * uint256(timeBonusBps)) / uint256(duration);
    uint256 bigger = (amount * uint256(biggerBonusBps)) / biggerRef;
    if (bigger > biggerBonusBps) bigger = biggerBonusBps;
    return (amount * (10_000 + timeBonus + bigger)) / 10_000;
  }

  function deposit(uint256 amount) external nonReentrant {
    if (finalized) revert BeehiveErrors.GenesisAlreadyFinalized();
    if (block.timestamp < start || block.timestamp >= deadline()) revert BeehiveErrors.GenesisClosed();
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    uint256 mintedShares = previewShares(amount);
    sharesOf[msg.sender] += mintedShares;
    totalShares += mintedShares;
    totalQuote += amount;
    quote.safeTransferFrom(msg.sender, address(this), amount);
    emit Deposited(msg.sender, amount, mintedShares);
  }

  function finalize() external nonReentrant {
    if (finalized) revert BeehiveErrors.GenesisAlreadyFinalized();
    if (block.timestamp < deadline()) revert BeehiveErrors.GenesisOpen();
    if (totalShares == 0) revert BeehiveErrors.ZeroAmount();

    uint256 cap = dues.maxSupply();
    dues.mint(address(this), cap);
    dues.disableMinting();

    uint256 seedDues = (cap * uint256(seedBps)) / 10_000;
    uint256 seedQuoteAmt = (totalQuote * uint256(seedBps)) / 10_000;
    claimableDues = cap - seedDues;

    if (seedDues > 0 && seedQuoteAmt > 0 && address(router) != address(0)) {
      IERC20(address(dues)).forceApprove(address(router), seedDues);
      quote.forceApprove(address(router), seedQuoteAmt);
      (,, uint256 liq) = router.addLiquidity(
        address(dues),
        address(quote),
        seedDues,
        seedQuoteAmt,
        0,
        0,
        address(this),
        block.timestamp
      );
      seededLp = liq;
      lpToken = _pairOf();
    }

    uint256 leftoverQuote = quote.balanceOf(address(this));
    if (leftoverQuote > 0 && address(revenueHub) != address(0)) {
      quote.forceApprove(address(revenueHub), leftoverQuote);
      revenueHub.notify(BeehiveTypes.RevenueSource.GenesisProceeds, address(quote), leftoverQuote);
    }

    finalized = true;
    emit Finalized(cap, seedDues, seedQuoteAmt, leftoverQuote);
  }

  function claim() external nonReentrant {
    if (!finalized) revert BeehiveErrors.GenesisNotFinalized();
    if (claimed[msg.sender]) revert BeehiveErrors.AlreadyClaimed();
    uint256 sh = sharesOf[msg.sender];
    if (sh == 0) revert BeehiveErrors.NothingToClaim();
    claimed[msg.sender] = true;
    uint256 amount = (claimableDues * sh) / totalShares;
    IERC20(address(dues)).safeTransfer(msg.sender, amount);
    emit Claimed(msg.sender, amount);
  }

  function _pairOf() private view returns (address) {
    return IUniswapV2Router02(address(router)).factory() == address(0)
      ? address(0)
      : _pairLookup();
  }

  function _pairLookup() private view returns (address) {
    address factory = router.factory();
    (bool ok, bytes memory ret) =
      factory.staticcall(abi.encodeWithSignature("getPair(address,address)", address(dues), address(quote)));
    if (!ok || ret.length < 32) return address(0);
    return abi.decode(ret, (address));
  }
}
