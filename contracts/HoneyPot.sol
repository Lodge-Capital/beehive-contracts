// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {IBeehiveLocks} from "contracts/interfaces/IBeehiveLocks.sol";

/// @notice Quarterly pot paid to stakes that stayed active for the entire epoch, pro rata by weight.
contract HoneyPot is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IBeehiveLocks public locks;
  address public revenueHub;
  uint64 public epochDuration;
  uint64 public epochStart;
  uint32 public epochId;

  uint256 public epochStartWeight;
  uint256 public epochExitWeight;

  mapping(uint32 => BeehiveTypes.Epoch) public epochs;
  mapping(uint32 => mapping(address => uint256)) public epochPot;
  mapping(uint256 => mapping(uint32 => mapping(address => bool))) public claimed;
  mapping(address => uint256) public accruing;

  address[] public trackedTokens;
  mapping(address => bool) public isTracked;

  uint8 internal constant MAX_CATCHUP = 4;

  event Credited(address indexed token, uint256 amount, uint32 indexed epoch);
  event EpochClosed(uint32 indexed id, uint64 start, uint64 end, uint256 eligibleWeight);
  event HoneyClaimed(uint256 indexed tokenId, address indexed token, uint32 indexed epoch, uint256 amount);

  constructor(address owner_, uint64 epochDuration_, uint64 epochStart_) Ownable(owner_) {
    if (epochDuration_ < 1 days) revert BeehiveErrors.OutOfBounds();
    epochDuration = epochDuration_;
    epochStart = epochStart_ == 0 ? uint64(block.timestamp) : epochStart_;
  }

  function setLocks(address locks_) external onlyOwner {
    if (locks_ == address(0)) revert BeehiveErrors.ZeroAddress();
    locks = IBeehiveLocks(locks_);
    if (epochStartWeight == 0) epochStartWeight = locks.totalWeight();
  }

  function setRevenueHub(address hub_) external onlyOwner {
    if (hub_ == address(0)) revert BeehiveErrors.ZeroAddress();
    revenueHub = hub_;
  }

  function setEpochDuration(uint64 duration_) external onlyOwner {
    if (duration_ < 1 days || duration_ > 730 days) revert BeehiveErrors.OutOfBounds();
    epochDuration = duration_;
  }

  /// @notice Launch-only alignment. Disabled after the first epoch is closed (handoff / live).
  function restartEpoch() external onlyOwner {
    if (epochId != 0) revert BeehiveErrors.OutOfBounds();
    epochStart = uint64(block.timestamp);
    epochStartWeight = address(locks) == address(0) ? 0 : locks.totalWeight();
    epochExitWeight = 0;
  }

  function noteLock(uint256, uint256 weight) external {
    if (msg.sender != address(locks)) revert BeehiveErrors.Unauthorized();
    if (block.timestamp <= epochStart && weight > 0) {
      epochStartWeight += weight;
    }
  }

  function noteUnlock(uint256 tokenId, uint256 weight, bool existedAtEpochStart) external {
    if (msg.sender != address(locks)) revert BeehiveErrors.Unauthorized();
    tokenId;
    // If the epoch already ended, this stake completed it; do not cut eligible weight.
    if (existedAtEpochStart && weight > 0 && !_due()) {
      epochExitWeight += weight;
    }
  }

  function settleOnUnlock(uint256 tokenId, address to) external nonReentrant {
    if (msg.sender != address(locks)) revert BeehiveErrors.Unauthorized();
    _closeDue(MAX_CATCHUP);
    uint32 closed = epochId;
    uint256 n = trackedTokens.length;
    for (uint32 id; id < closed; ++id) {
      if (!isEligibleForEpoch(tokenId, id)) continue;
      for (uint256 i; i < n; ++i) {
        address token = trackedTokens[i];
        if (claimed[tokenId][id][token]) continue;
        uint256 pot = epochPot[id][token];
        uint256 eligible = epochs[id].eligibleWeight;
        uint256 weight = locks.weightOf(tokenId);
        if (pot == 0 || eligible == 0 || weight == 0) continue;
        claimed[tokenId][id][token] = true;
        uint256 amount = (pot * weight) / eligible;
        IERC20(token).safeTransfer(to, amount);
        emit HoneyClaimed(tokenId, token, id, amount);
      }
    }
  }

  function credit(address token, uint256 amount) external {
    if (msg.sender != revenueHub) revert BeehiveErrors.Unauthorized();
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    _closeDue(MAX_CATCHUP);
    if (!isTracked[token]) {
      isTracked[token] = true;
      trackedTokens.push(token);
    }
    accruing[token] += amount;
    emit Credited(token, amount, epochId);
  }

  function potSize(address token) external view returns (uint256) {
    return accruing[token];
  }

  function countdown() public view returns (uint256) {
    uint64 end_ = epochStart + epochDuration;
    if (block.timestamp >= end_) return 0;
    return uint256(end_ - uint64(block.timestamp));
  }

  function currentEligibleWeight() public view returns (uint256) {
    if (epochExitWeight >= epochStartWeight) return 0;
    return epochStartWeight - epochExitWeight;
  }

  function isEligible(uint256 tokenId) public view returns (bool) {
    return _eligibleFor(tokenId, epochStart, uint64(block.timestamp), false);
  }

  function isEligibleForEpoch(uint256 tokenId, uint32 id) public view returns (bool) {
    BeehiveTypes.Epoch memory e = epochs[id];
    if (!e.closed) return false;
    return _eligibleFor(tokenId, e.start, e.end, true);
  }

  function closeEpoch() external nonReentrant {
    if (!_due()) {
      if (block.timestamp < uint256(epochStart) + uint256(epochDuration)) revert BeehiveErrors.EpochNotEnded();
      revert BeehiveErrors.EpochAlreadyClosed();
    }
    _snapshotAndRoll();
  }

  function claim(uint256 tokenId, uint32 id, address token) external nonReentrant returns (uint256 amount) {
    _closeDue(MAX_CATCHUP);
    if (msg.sender != locks.ownerOf(tokenId)) revert BeehiveErrors.NotStakeOwner();
    if (!epochs[id].closed) revert BeehiveErrors.EpochNotEnded();
    if (claimed[tokenId][id][token]) revert BeehiveErrors.AlreadyClaimed();
    if (!isEligibleForEpoch(tokenId, id)) revert BeehiveErrors.NotEligible();

    uint256 weight = locks.weightOf(tokenId);
    uint256 eligible = epochs[id].eligibleWeight;
    uint256 pot = epochPot[id][token];
    if (eligible == 0 || pot == 0 || weight == 0) revert BeehiveErrors.NothingToClaim();

    claimed[tokenId][id][token] = true;
    amount = (pot * weight) / eligible;
    IERC20(token).safeTransfer(msg.sender, amount);
    emit HoneyClaimed(tokenId, token, id, amount);
  }

  function _due() internal view returns (bool) {
    return block.timestamp >= uint256(epochStart) + uint256(epochDuration) && !epochs[epochId].closed;
  }

  function _closeDue(uint8 maxCatchup) internal {
    uint8 n;
    while (_due() && n < maxCatchup) {
      _snapshotAndRoll();
      unchecked {
        ++n;
      }
    }
  }

  function _snapshotAndRoll() internal {
    uint64 end_ = epochStart + epochDuration;
    uint256 eligible = currentEligibleWeight();
    uint256 n = trackedTokens.length;
    for (uint256 i; i < n; ++i) {
      address token = trackedTokens[i];
      epochPot[epochId][token] = accruing[token];
      accruing[token] = 0;
    }
    epochs[epochId] =
      BeehiveTypes.Epoch({start: epochStart, end: end_, pot: 0, eligibleWeight: eligible, closed: true});
    emit EpochClosed(epochId, epochStart, end_, eligible);

    epochId += 1;
    epochStart = end_;
    epochStartWeight = address(locks) == address(0) ? 0 : locks.totalWeight();
    epochExitWeight = 0;
  }

  function _eligibleFor(uint256 tokenId, uint64 start_, uint64 end_, bool requireClosedWindow)
    private
    view
    returns (bool)
  {
    BeehiveTypes.Stake memory s = locks.stakeOf(tokenId);
    if (s.start == 0 || s.weight == 0) return false;
    if (s.start > start_) return false;
    if (s.unlockedAt != 0 && s.unlockedAt < end_) return false;
    if (requireClosedWindow && s.start > start_) return false;
    return true;
  }
}
