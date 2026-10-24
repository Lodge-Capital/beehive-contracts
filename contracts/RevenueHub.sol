// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {IBeehiveLocks} from "contracts/interfaces/IBeehiveLocks.sol";
import {IHoneyPot} from "contracts/interfaces/IHoneyPot.sol";

/// @notice Routes every protocol inflow to stakers, the Honey Pot, and buyback. No inflation.
contract RevenueHub is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IBeehiveLocks public locks;
  IHoneyPot public honeyPot;
  address public buyback;

  uint16 public honeyShareBps;
  uint16 public stakerShareBps;
  uint16 public buybackShareBps;

  mapping(address => bool) public approvedSource;
  mapping(address => bool) public trustedModule;

  event RevenueInflow(
    BeehiveTypes.RevenueSource indexed source, address indexed token, uint256 amount, address indexed from
  );
  event Split(address indexed token, uint256 toStakers, uint256 toHoney, uint256 toBuyback);
  event ApprovedSourceUpdated(address indexed source, bool allowed);
  event SharesUpdated(uint16 honey, uint16 stakers, uint16 buybackBps);
  event ModulesUpdated(address locks, address honey, address buyback);

  constructor(address owner_, uint16 honeyBps_, uint16 stakerBps_, uint16 buybackBps_) Ownable(owner_) {
    _setShares(honeyBps_, stakerBps_, buybackBps_);
  }

  function setModules(address locks_, address honey_, address buyback_) external onlyOwner {
    if (locks_ == address(0) || honey_ == address(0) || buyback_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (address(locks) != address(0)) {
      trustedModule[address(locks)] = false;
      trustedModule[address(honeyPot)] = false;
      trustedModule[buyback] = false;
    }
    locks = IBeehiveLocks(locks_);
    honeyPot = IHoneyPot(honey_);
    buyback = buyback_;
    trustedModule[locks_] = true;
    trustedModule[honey_] = true;
    trustedModule[buyback_] = true;
    emit ModulesUpdated(locks_, honey_, buyback_);
  }

  function setApprovedSource(address source, bool allowed) external onlyOwner {
    if (source == address(0)) revert BeehiveErrors.ZeroAddress();
    approvedSource[source] = allowed;
    emit ApprovedSourceUpdated(source, allowed);
  }

  function setShares(uint16 honeyBps_, uint16 stakerBps_, uint16 buybackBps_) external onlyOwner {
    _setShares(honeyBps_, stakerBps_, buybackBps_);
  }

  /// @notice Called after the caller has already transferred `amount` of `token` here.
  function onInflow(BeehiveTypes.RevenueSource source, address token, uint256 amount) external nonReentrant {
    if (!trustedModule[msg.sender] && !approvedSource[msg.sender]) revert BeehiveErrors.NotApprovedSource();
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    emit RevenueInflow(source, token, amount, msg.sender);
    _split(token, amount);
  }

  /// @notice Pull-based hook for LodgeFi deposits and other approved protocol revenue.
  function notify(BeehiveTypes.RevenueSource source, address token, uint256 amount) external nonReentrant {
    if (source == BeehiveTypes.RevenueSource.LodgeFiDeposit || source == BeehiveTypes.RevenueSource.ProtocolHook) {
      if (!approvedSource[msg.sender]) revert BeehiveErrors.NotApprovedSource();
    } else if (!trustedModule[msg.sender] && !approvedSource[msg.sender]) {
      revert BeehiveErrors.NotApprovedSource();
    }
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    emit RevenueInflow(source, token, amount, msg.sender);
    _split(token, amount);
  }

  function _setShares(uint16 honeyBps_, uint16 stakerBps_, uint16 buybackBps_) private {
    if (uint256(honeyBps_) + uint256(stakerBps_) + uint256(buybackBps_) != 10_000) revert BeehiveErrors.InvalidSplit();
    if (honeyBps_ > 9_000 || stakerBps_ > 9_000 || buybackBps_ > 9_000) revert BeehiveErrors.OutOfBounds();
    honeyShareBps = honeyBps_;
    stakerShareBps = stakerBps_;
    buybackShareBps = buybackBps_;
    emit SharesUpdated(honeyBps_, stakerBps_, buybackBps_);
  }

  function _split(address token, uint256 amount) private {
    uint256 toHoney = (amount * uint256(honeyShareBps)) / 10_000;
    uint256 toBuyback = (amount * uint256(buybackShareBps)) / 10_000;
    uint256 toStakers = amount - toHoney - toBuyback;

    if (toHoney > 0) {
      IERC20(token).safeTransfer(address(honeyPot), toHoney);
      honeyPot.credit(token, toHoney);
    }
    if (toBuyback > 0) {
      IERC20(token).safeTransfer(buyback, toBuyback);
    }
    if (toStakers > 0) {
      if (locks.totalWeight() == 0) {
        IERC20(token).safeTransfer(address(honeyPot), toStakers);
        honeyPot.credit(token, toStakers);
        toHoney += toStakers;
        toStakers = 0;
      } else {
        IERC20(token).safeTransfer(address(locks), toStakers);
        locks.creditReward(token, toStakers);
      }
    }
    emit Split(token, toStakers, toHoney, toBuyback);
  }
}
