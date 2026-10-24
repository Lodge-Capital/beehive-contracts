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

/// @notice Quote-token marketplace for stake NFTs. No self-buy, minimum listing time, no trading halt.
contract StakeMarket is Ownable, ReentrancyGuard, IERC721Receiver {
  using SafeERC20 for IERC20;

  BeehiveLocks public immutable locks;
  IERC20 public immutable quote;
  IRevenueHub public revenueHub;
  ITwapOracle public oracle;

  uint16 public feeBps;
  uint32 public minListingSeconds;
  mapping(uint256 => BeehiveTypes.Listing) public listings;

  event Listed(uint256 indexed tokenId, address indexed seller, uint256 ask, uint64 listedAt);
  event Canceled(uint256 indexed tokenId, address indexed seller);
  event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 ask, uint256 fee);

  constructor(
    address locks_,
    address quote_,
    address owner_,
    uint16 feeBps_,
    uint32 minListingSeconds_
  ) Ownable(owner_) {
    if (locks_ == address(0) || quote_ == address(0) || owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (feeBps_ > 1_500) revert BeehiveErrors.OutOfBounds();
    if (minListingSeconds_ < 60 || minListingSeconds_ > 7 days) revert BeehiveErrors.OutOfBounds();
    locks = BeehiveLocks(locks_);
    quote = IERC20(quote_);
    feeBps = feeBps_;
    minListingSeconds = minListingSeconds_;
  }

  function setRevenueHub(address hub_) external onlyOwner {
    if (hub_ == address(0)) revert BeehiveErrors.ZeroAddress();
    revenueHub = IRevenueHub(hub_);
  }

  function setOracle(address oracle_) external onlyOwner {
    if (oracle_ == address(0)) revert BeehiveErrors.ZeroAddress();
    oracle = ITwapOracle(oracle_);
  }

  function setFeeBps(uint16 feeBps_) external onlyOwner {
    if (feeBps_ > 1_500) revert BeehiveErrors.OutOfBounds();
    feeBps = feeBps_;
  }

  function setMinListingSeconds(uint32 secs_) external onlyOwner {
    if (secs_ < 60 || secs_ > 7 days) revert BeehiveErrors.OutOfBounds();
    minListingSeconds = secs_;
  }

  function list(uint256 tokenId, uint256 ask) external nonReentrant {
    if (ask == 0) revert BeehiveErrors.InvalidAsk();
    if (listings[tokenId].active) revert BeehiveErrors.AlreadyListed();
    if (locks.ownerOf(tokenId) != msg.sender) revert BeehiveErrors.NotStakeOwner();
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    if (s.unlockedAt != 0 || s.lpAmount == 0) revert BeehiveErrors.StakeNotActive();
    locks.safeTransferFrom(msg.sender, address(this), tokenId);
    listings[tokenId] =
      BeehiveTypes.Listing({seller: msg.sender, ask: ask, listedAt: uint64(block.timestamp), active: true});
    emit Listed(tokenId, msg.sender, ask, uint64(block.timestamp));
  }

  function cancel(uint256 tokenId) external nonReentrant {
    BeehiveTypes.Listing memory l = listings[tokenId];
    if (!l.active) revert BeehiveErrors.NotListed();
    if (l.seller != msg.sender) revert BeehiveErrors.Unauthorized();
    listings[tokenId].active = false;
    locks.safeTransferFrom(address(this), l.seller, tokenId);
    emit Canceled(tokenId, l.seller);
  }

  function buy(uint256 tokenId) external nonReentrant {
    BeehiveTypes.Listing memory l = listings[tokenId];
    if (!l.active) revert BeehiveErrors.NotListed();
    if (msg.sender == l.seller) revert BeehiveErrors.SelfTrade();
    if (block.timestamp < uint256(l.listedAt) + uint256(minListingSeconds)) revert BeehiveErrors.ListingTooFresh();

    listings[tokenId].active = false;
    uint256 fee = (l.ask * uint256(feeBps)) / 10_000;
    uint256 proceeds = l.ask - fee;
    quote.safeTransferFrom(msg.sender, l.seller, proceeds);
    if (fee > 0 && address(revenueHub) != address(0)) {
      quote.safeTransferFrom(msg.sender, address(revenueHub), fee);
      revenueHub.onInflow(BeehiveTypes.RevenueSource.MarketplaceFee, address(quote), fee);
    }
    locks.safeTransferFrom(address(this), msg.sender, tokenId);
    emit Bought(tokenId, msg.sender, l.seller, l.ask, fee);
  }

  /// @notice Matured LP quote value vs ask so discounts (typically up to ~40%) are visible.
  function quoteMaturedValue(uint256 tokenId)
    external
    view
    returns (uint256 maturedQuote, uint256 ask, int256 discountBps)
  {
    BeehiveTypes.Listing memory l = listings[tokenId];
    if (!l.active) revert BeehiveErrors.NotListed();
    ask = l.ask;
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    maturedQuote = address(oracle) == address(0) ? 0 : oracle.consultLpValue(s.lpAmount);
    if (maturedQuote == 0) return (maturedQuote, ask, 0);
    discountBps = (int256(maturedQuote) - int256(ask)) * 10_000 / int256(maturedQuote);
  }

  function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
    if (msg.sender != address(locks)) revert BeehiveErrors.Unauthorized();
    return this.onERC721Received.selector;
  }
}
