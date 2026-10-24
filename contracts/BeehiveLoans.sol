// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {BeehiveLocks} from "contracts/BeehiveLocks.sol";
import {IRevenueHub} from "contracts/interfaces/IRevenueHub.sol";
import {ITwapOracle} from "contracts/interfaces/ITwapOracle.sol";

/// @notice NFT-escrowed loans against LP value from a TWAP oracle. Lenders deposit and withdraw.
contract BeehiveLoans is Ownable, ReentrancyGuard, IERC721Receiver {
  using SafeERC20 for IERC20;

  uint256 internal constant YEAR = 365 days;

  BeehiveLocks public immutable locks;
  IERC20 public immutable quote;
  ITwapOracle public oracle;
  IRevenueHub public revenueHub;

  uint16 public ltvBps;
  uint16 public liqThresholdBps;
  uint16 public interestAprBps;
  uint16 public stakerInterestShareBps;
  uint32 public auctionDuration;
  uint16 public auctionStartBps;

  uint256 public totalShares;
  uint256 public totalPrincipal;
  mapping(address => uint256) public sharesOf;
  mapping(uint256 => BeehiveTypes.Loan) public loans;
  mapping(uint256 => BeehiveTypes.Auction) public auctions;

  event Funded(address indexed provider, uint256 amount, uint256 shares);
  event Withdrawn(address indexed provider, uint256 shares, uint256 amount);
  event Borrowed(uint256 indexed tokenId, address indexed borrower, uint256 amount);
  event Repaid(uint256 indexed tokenId, address indexed borrower, uint256 principal, uint256 interest);
  event AuctionStarted(uint256 indexed tokenId, uint256 startPrice, uint256 endPrice, uint64 duration);
  event Liquidated(
    uint256 indexed tokenId, address indexed bidder, uint256 price, uint256 debt, uint256 surplus, address borrower
  );
  event LoanParamsUpdated(uint16 ltv, uint16 liq, uint16 apr, uint16 stakerShare);

  constructor(
    address locks_,
    address quote_,
    address owner_,
    uint16 ltvBps_,
    uint16 liqThresholdBps_,
    uint16 interestAprBps_,
    uint16 stakerInterestShareBps_,
    uint32 auctionDuration_,
    uint16 auctionStartBps_
  ) Ownable(owner_) {
    if (locks_ == address(0) || quote_ == address(0) || owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    _validateLoanParams(ltvBps_, liqThresholdBps_, interestAprBps_, stakerInterestShareBps_);
    if (auctionDuration_ < 1 hours || auctionDuration_ > 14 days) revert BeehiveErrors.OutOfBounds();
    if (auctionStartBps_ < 10_000 || auctionStartBps_ > 20_000) revert BeehiveErrors.OutOfBounds();
    locks = BeehiveLocks(locks_);
    quote = IERC20(quote_);
    ltvBps = ltvBps_;
    liqThresholdBps = liqThresholdBps_;
    interestAprBps = interestAprBps_;
    stakerInterestShareBps = stakerInterestShareBps_;
    auctionDuration = auctionDuration_;
    auctionStartBps = auctionStartBps_;
  }

  function setOracle(address oracle_) external onlyOwner {
    if (oracle_ == address(0)) revert BeehiveErrors.ZeroAddress();
    oracle = ITwapOracle(oracle_);
  }

  function setRevenueHub(address hub_) external onlyOwner {
    if (hub_ == address(0)) revert BeehiveErrors.ZeroAddress();
    revenueHub = IRevenueHub(hub_);
  }

  function setLoanParams(uint16 ltv_, uint16 liq_, uint16 apr_, uint16 stakerShare_) external onlyOwner {
    _validateLoanParams(ltv_, liq_, apr_, stakerShare_);
    ltvBps = ltv_;
    liqThresholdBps = liq_;
    interestAprBps = apr_;
    stakerInterestShareBps = stakerShare_;
    emit LoanParamsUpdated(ltv_, liq_, apr_, stakerShare_);
  }

  function setAuctionParams(uint32 duration_, uint16 startBps_) external onlyOwner {
    if (duration_ < 1 hours || duration_ > 14 days) revert BeehiveErrors.OutOfBounds();
    if (startBps_ < 10_000 || startBps_ > 20_000) revert BeehiveErrors.OutOfBounds();
    auctionDuration = duration_;
    auctionStartBps = startBps_;
  }

  function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    uint256 assets = totalAssets();
    shares = totalShares == 0 || assets == 0 ? amount : (amount * totalShares) / assets;
    if (shares == 0) revert BeehiveErrors.ZeroAmount();
    sharesOf[msg.sender] += shares;
    totalShares += shares;
    quote.safeTransferFrom(msg.sender, address(this), amount);
    emit Funded(msg.sender, amount, shares);
  }

  function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
    if (shares == 0 || shares > sharesOf[msg.sender]) revert BeehiveErrors.ZeroAmount();
    amount = (shares * totalAssets()) / totalShares;
    uint256 liquid = quote.balanceOf(address(this));
    if (amount > liquid) revert BeehiveErrors.WithdrawLimited();
    sharesOf[msg.sender] -= shares;
    totalShares -= shares;
    quote.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, shares, amount);
  }

  function totalAssets() public view returns (uint256) {
    return quote.balanceOf(address(this)) + totalPrincipal + _allAccruedToLenders();
  }

  function maxBorrow(uint256 tokenId) public view returns (uint256) {
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    uint256 value = oracle.consultLpValue(s.lpAmount);
    return (value * uint256(ltvBps)) / 10_000;
  }

  function debtOf(uint256 tokenId) public view returns (uint256 principal, uint256 interest) {
    BeehiveTypes.Loan memory l = loans[tokenId];
    if (!l.open) return (0, 0);
    principal = l.principal;
    interest = _interest(l.principal, l.start);
  }

  function healthFactor(uint256 tokenId) public view returns (uint256) {
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    (uint256 p, uint256 i) = debtOf(tokenId);
    uint256 debt = p + i;
    if (debt == 0) return type(uint256).max;
    uint256 value = oracle.consultLpValue(s.lpAmount);
    return (value * 1e18) / debt;
  }

  function isLiquidatable(uint256 tokenId) public view returns (bool) {
    BeehiveTypes.Loan memory l = loans[tokenId];
    if (!l.open) return false;
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    if (block.timestamp >= s.end) return true;
    (uint256 p, uint256 i) = debtOf(tokenId);
    uint256 value = oracle.consultLpValue(s.lpAmount);
    return p + i > (value * uint256(liqThresholdBps)) / 10_000;
  }

  function borrow(uint256 tokenId, uint256 amount) external nonReentrant {
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    if (loans[tokenId].open) revert BeehiveErrors.LoanOpen();
    if (locks.ownerOf(tokenId) != msg.sender) revert BeehiveErrors.NotStakeOwner();
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    if (s.unlockedAt != 0 || block.timestamp >= s.end) revert BeehiveErrors.StakeNotActive();
    uint256 limit = maxBorrow(tokenId);
    if (amount > limit) revert BeehiveErrors.ExceedsLTV();
    if (quote.balanceOf(address(this)) < amount) revert BeehiveErrors.InsufficientLiquidity();

    locks.safeTransferFrom(msg.sender, address(this), tokenId);
    loans[tokenId] = BeehiveTypes.Loan({
      borrower: msg.sender,
      principal: amount,
      start: uint64(block.timestamp),
      lastAccrual: uint64(block.timestamp),
      open: true
    });
    totalPrincipal += amount;
    quote.safeTransfer(msg.sender, amount);
    emit Borrowed(tokenId, msg.sender, amount);
  }

  function repay(uint256 tokenId) external nonReentrant {
    BeehiveTypes.Loan memory l = loans[tokenId];
    if (!l.open) revert BeehiveErrors.NoLoan();
    if (l.borrower != msg.sender) revert BeehiveErrors.Unauthorized();
    (uint256 p, uint256 interest) = debtOf(tokenId);
    _closeLoan(tokenId, p, interest, msg.sender, l.borrower, true);
    emit Repaid(tokenId, l.borrower, p, interest);
  }

  function startAuction(uint256 tokenId) external nonReentrant {
    if (!isLiquidatable(tokenId)) revert BeehiveErrors.NotLiquidatable();
    if (auctions[tokenId].active) revert BeehiveErrors.AuctionActive();
    (uint256 p, uint256 i) = debtOf(tokenId);
    uint256 debt = p + i;
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    uint256 value = oracle.consultLpValue(s.lpAmount);
    uint256 startPrice = (value * uint256(auctionStartBps)) / 10_000;
    if (startPrice < debt) startPrice = debt;
    auctions[tokenId] = BeehiveTypes.Auction({
      startPrice: startPrice,
      endPrice: debt,
      startTime: uint64(block.timestamp),
      duration: uint64(auctionDuration),
      active: true
    });
    emit AuctionStarted(tokenId, startPrice, debt, uint64(auctionDuration));
  }

  function currentAuctionPrice(uint256 tokenId) public view returns (uint256) {
    BeehiveTypes.Auction memory a = auctions[tokenId];
    if (!a.active) revert BeehiveErrors.AuctionNotActive();
    uint256 elapsed = block.timestamp - uint256(a.startTime);
    if (elapsed >= a.duration) return a.endPrice;
    uint256 drop = a.startPrice - a.endPrice;
    return a.startPrice - (drop * elapsed) / uint256(a.duration);
  }

  function bid(uint256 tokenId) external nonReentrant {
    BeehiveTypes.Auction memory a = auctions[tokenId];
    if (!a.active) revert BeehiveErrors.AuctionNotActive();
    BeehiveTypes.Loan memory l = loans[tokenId];
    if (!l.open) revert BeehiveErrors.NoLoan();
    uint256 price = currentAuctionPrice(tokenId);
    (uint256 p, uint256 interest) = debtOf(tokenId);
    uint256 debt = p + interest;
    if (price < debt) price = debt;
    quote.safeTransferFrom(msg.sender, address(this), price);
    uint256 surplus = price - debt;
    auctions[tokenId].active = false;
    _applyRepayment(p, interest);
    loans[tokenId].open = false;
    loans[tokenId].principal = 0;
    if (surplus > 0) quote.safeTransfer(l.borrower, surplus);
    locks.safeTransferFrom(address(this), msg.sender, tokenId);
    emit Liquidated(tokenId, msg.sender, price, debt, surplus, l.borrower);
  }

  function _closeLoan(uint256 tokenId, uint256 p, uint256 interest, address payer, address borrower, bool returnNft)
    private
  {
    uint256 owed = p + interest;
    quote.safeTransferFrom(payer, address(this), owed);
    _applyRepayment(p, interest);
    loans[tokenId].open = false;
    loans[tokenId].principal = 0;
    auctions[tokenId].active = false;
    if (returnNft) locks.safeTransferFrom(address(this), borrower, tokenId);
  }

  function _applyRepayment(uint256 p, uint256 interest) private {
    if (totalPrincipal >= p) totalPrincipal -= p;
    else totalPrincipal = 0;
    if (interest > 0 && address(revenueHub) != address(0) && stakerInterestShareBps > 0) {
      uint256 toStakers = (interest * uint256(stakerInterestShareBps)) / 10_000;
      if (toStakers > 0) {
        quote.safeTransfer(address(revenueHub), toStakers);
        revenueHub.onInflow(BeehiveTypes.RevenueSource.LoanInterest, address(quote), toStakers);
      }
    }
  }

  function _interest(uint256 principal, uint64 start_) private view returns (uint256) {
    if (principal == 0) return 0;
    uint256 dt = block.timestamp - uint256(start_);
    return (principal * uint256(interestAprBps) * dt) / YEAR / 10_000;
  }

  function _allAccruedToLenders() private view returns (uint256 acc) {
    // Conservative: do not mark unrealized interest as withdrawable until repaid.
    return 0;
  }

  function _validateLoanParams(uint16 ltv_, uint16 liq_, uint16 apr_, uint16 stakerShare_) private pure {
    if (ltv_ < 2_000 || ltv_ > 4_000) revert BeehiveErrors.OutOfBounds();
    if (liq_ < ltv_ || liq_ > 5_000) revert BeehiveErrors.OutOfBounds();
    if (apr_ > 5_000 || stakerShare_ > 10_000) revert BeehiveErrors.OutOfBounds();
  }

  function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
    if (msg.sender != address(locks)) revert BeehiveErrors.Unauthorized();
    return this.onERC721Received.selector;
  }
}
