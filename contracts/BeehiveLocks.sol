// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {BeehiveTypes} from "contracts/BeehiveTypes.sol";
import {IRevenueHub} from "contracts/interfaces/IRevenueHub.sol";
import {IHoneyPot} from "contracts/interfaces/IHoneyPot.sol";

/// @notice Transferable ERC-721 stake of DUES/quote LP. Weight is fixed (no decaying voting power).
contract BeehiveLocks is ERC721, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  uint256 internal constant PRECISION = 1e18;

  IERC20 public immutable lpToken;
  uint32 public immutable minLock;
  uint32 public immutable maxLock;
  uint16 public immutable longerBonusBps;
  uint16 public immutable biggerBonusBps;
  uint256 public immutable biggerRef;

  IRevenueHub public revenueHub;
  IHoneyPot public honeyPot;

  uint16 public earlySlashBps;
  uint32 public lateGrace;
  uint16 public latePenaltyBpsPerDay;
  uint16 public maxLatePenaltyBps;

  uint256 public nextId;
  uint256 public totalWeight;
  uint256 public totalLockedLp;

  mapping(uint256 => BeehiveTypes.Stake) internal _stakes;
  mapping(address => uint256) public rewardPerWeight;
  mapping(uint256 => mapping(address => uint256)) public rewardPaid;
  mapping(uint256 => mapping(address => uint256)) public accrued;
  address[] public rewardTokens;
  mapping(address => bool) public isRewardToken;

  event Locked(address indexed owner, uint256 indexed tokenId, uint256 lpAmount, uint256 weight, uint64 end);
  event Unlocked(address indexed owner, uint256 indexed tokenId, uint256 returned, uint256 slashed, bool early);
  event RewardCredited(address indexed token, uint256 amount);
  event RewardClaimed(uint256 indexed tokenId, address indexed token, address indexed to, uint256 amount);
  event SlashParamsUpdated(uint16 earlyBps, uint32 grace, uint16 latePerDay, uint16 lateMax);

  constructor(
    string memory name_,
    string memory symbol_,
    address lpToken_,
    address owner_,
    uint32 minLock_,
    uint32 maxLock_,
    uint16 earlySlashBps_,
    uint32 lateGrace_,
    uint16 latePenaltyBpsPerDay_,
    uint16 maxLatePenaltyBps_,
    uint16 longerBonusBps_,
    uint16 biggerBonusBps_,
    uint256 biggerRef_
  ) ERC721(name_, symbol_) Ownable(owner_) {
    if (lpToken_ == address(0) || owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (minLock_ == 0 || maxLock_ <= minLock_) revert BeehiveErrors.InvalidLockDuration();
    if (earlySlashBps_ < 1_000 || earlySlashBps_ > 8_000) revert BeehiveErrors.OutOfBounds();
    if (biggerRef_ == 0) revert BeehiveErrors.ZeroAmount();
    lpToken = IERC20(lpToken_);
    minLock = minLock_;
    maxLock = maxLock_;
    earlySlashBps = earlySlashBps_;
    lateGrace = lateGrace_;
    latePenaltyBpsPerDay = latePenaltyBpsPerDay_;
    maxLatePenaltyBps = maxLatePenaltyBps_;
    longerBonusBps = longerBonusBps_;
    biggerBonusBps = biggerBonusBps_;
    biggerRef = biggerRef_;
  }

  function setModules(address revenue_, address honey_) external onlyOwner {
    if (revenue_ == address(0) || honey_ == address(0)) revert BeehiveErrors.ZeroAddress();
    revenueHub = IRevenueHub(revenue_);
    honeyPot = IHoneyPot(honey_);
  }

  function setSlashParams(uint16 earlyBps_, uint32 grace_, uint16 latePerDay_, uint16 lateMax_) external onlyOwner {
    if (earlyBps_ < 1_000 || earlyBps_ > 8_000) revert BeehiveErrors.OutOfBounds();
    if (lateMax_ > 8_000 || latePerDay_ > 500) revert BeehiveErrors.OutOfBounds();
    earlySlashBps = earlyBps_;
    lateGrace = grace_;
    latePenaltyBpsPerDay = latePerDay_;
    maxLatePenaltyBps = lateMax_;
    emit SlashParamsUpdated(earlyBps_, grace_, latePerDay_, lateMax_);
  }

  function stakeOf(uint256 tokenId) external view returns (BeehiveTypes.Stake memory) {
    return _stakes[tokenId];
  }

  function weightOf(uint256 tokenId) public view returns (uint256) {
    return _stakes[tokenId].weight;
  }

  function computeWeight(uint256 amount, uint256 duration) public view returns (uint256) {
    if (amount == 0) return 0;
    uint256 span = uint256(maxLock) - uint256(minLock);
    uint256 longer;
    if (duration > minLock && span > 0) {
      longer = ((duration - uint256(minLock)) * uint256(longerBonusBps)) / span;
    }
    uint256 bigger = (amount * uint256(biggerBonusBps)) / biggerRef;
    if (bigger > biggerBonusBps) bigger = biggerBonusBps;
    return (amount * (10_000 + longer + bigger)) / 10_000;
  }

  function lock(uint256 lpAmount, uint256 duration) external nonReentrant returns (uint256 tokenId) {
    if (lpAmount == 0) revert BeehiveErrors.ZeroAmount();
    if (duration < minLock || duration > maxLock) revert BeehiveErrors.InvalidLockDuration();
    uint256 weight = computeWeight(lpAmount, duration);
    tokenId = ++nextId;
    uint64 end = uint64(block.timestamp + duration);
    _stakes[tokenId] = BeehiveTypes.Stake({
      lpAmount: lpAmount,
      weight: weight,
      start: uint64(block.timestamp),
      end: end,
      unlockedAt: 0
    });
    totalWeight += weight;
    totalLockedLp += lpAmount;
    _checkpointNew(tokenId, weight);
    lpToken.safeTransferFrom(msg.sender, address(this), lpAmount);
    _safeMint(msg.sender, tokenId);
    if (address(honeyPot) != address(0)) {
      HoneyPotHook(address(honeyPot)).noteLock(tokenId, weight);
    }
    emit Locked(msg.sender, tokenId, lpAmount, weight, end);
  }

  function unlock(uint256 tokenId) external nonReentrant {
    if (ownerOf(tokenId) != msg.sender) revert BeehiveErrors.NotStakeOwner();
    BeehiveTypes.Stake storage s = _stakes[tokenId];
    if (s.unlockedAt != 0 || s.lpAmount == 0) revert BeehiveErrors.StakeNotActive();

    _harvestAll(tokenId, msg.sender);

    bool early = block.timestamp < s.end;
    uint16 penaltyBps = early ? earlySlashBps : _latePenaltyBps(s.end);
    uint256 slashed = (s.lpAmount * uint256(penaltyBps)) / 10_000;
    uint256 returned = s.lpAmount - slashed;

    bool existedAtEpochStart = address(honeyPot) != address(0) && s.start <= honeyPotEpochStart();
    uint256 unlockedWeight = s.weight;
    totalWeight -= s.weight;
    totalLockedLp -= s.lpAmount;
    s.unlockedAt = uint64(block.timestamp);
    s.lpAmount = 0;

    if (address(honeyPot) != address(0)) {
      if (existedAtEpochStart) {
        HoneyPotHook(address(honeyPot)).noteUnlock(tokenId, unlockedWeight, true);
      }
      HoneyPotHook(address(honeyPot)).settleOnUnlock(tokenId, msg.sender);
    }

    if (slashed > 0 && address(revenueHub) != address(0)) {
      lpToken.safeTransfer(address(revenueHub), slashed);
      revenueHub.onInflow(
        early ? BeehiveTypes.RevenueSource.EarlySlash : BeehiveTypes.RevenueSource.LatePenalty,
        address(lpToken),
        slashed
      );
    }
    if (returned > 0) lpToken.safeTransfer(msg.sender, returned);
    _burn(tokenId);
    emit Unlocked(msg.sender, tokenId, returned, slashed, early);
  }

  function claim(uint256 tokenId, address token) external nonReentrant returns (uint256) {
    if (ownerOf(tokenId) != msg.sender) revert BeehiveErrors.NotStakeOwner();
    uint256 amount = _harvest(tokenId, token, msg.sender);
    if (amount == 0) revert BeehiveErrors.NothingToClaim();
    return amount;
  }

  function pending(uint256 tokenId, address token) public view returns (uint256) {
    BeehiveTypes.Stake memory s = _stakes[tokenId];
    if (s.weight == 0) return accrued[tokenId][token];
    uint256 accum = (s.weight * rewardPerWeight[token]) / PRECISION;
    uint256 already = rewardPaid[tokenId][token];
    uint256 extra = accum > already ? accum - already : 0;
    return accrued[tokenId][token] + extra;
  }

  function creditReward(address token, uint256 amount) external {
    if (msg.sender != address(revenueHub)) revert BeehiveErrors.Unauthorized();
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    if (totalWeight == 0) revert BeehiveErrors.ZeroAmount();
    if (!isRewardToken[token]) {
      isRewardToken[token] = true;
      rewardTokens.push(token);
    }
    rewardPerWeight[token] += (amount * PRECISION) / totalWeight;
    emit RewardCredited(token, amount);
  }

  function harvest(uint256 tokenId, address token, address to) external returns (uint256) {
    if (ownerOf(tokenId) != msg.sender) revert BeehiveErrors.NotStakeOwner();
    return _harvest(tokenId, token, to);
  }

  function previewUnlock(uint256 tokenId) external view returns (uint256 returned, uint256 slashed, bool early) {
    BeehiveTypes.Stake memory s = _stakes[tokenId];
    early = block.timestamp < s.end;
    uint16 penaltyBps = early ? earlySlashBps : _latePenaltyBps(s.end);
    slashed = (s.lpAmount * uint256(penaltyBps)) / 10_000;
    returned = s.lpAmount - slashed;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireOwned(tokenId);
    BeehiveTypes.Stake memory s = _stakes[tokenId];
    return string.concat("beehive-stake-", _u(tokenId), "-", _u(s.lpAmount), "-", _u(s.weight), "-", _u(s.end));
  }

  function honeyPotEpochStart() public view returns (uint64) {
    if (address(honeyPot) == address(0)) return 0;
    return HoneyPotView(address(honeyPot)).epochStart();
  }

  function _latePenaltyBps(uint64 end) internal view returns (uint16) {
    uint256 graceEnd = uint256(end) + uint256(lateGrace);
    if (block.timestamp <= graceEnd) return 0;
    uint256 daysLate = (block.timestamp - graceEnd) / 1 days;
    uint256 bps = daysLate * uint256(latePenaltyBpsPerDay);
    if (bps > maxLatePenaltyBps) bps = maxLatePenaltyBps;
    return uint16(bps);
  }

  function _checkpointNew(uint256 tokenId, uint256 weight) private {
    uint256 n = rewardTokens.length;
    for (uint256 i; i < n; ++i) {
      address token = rewardTokens[i];
      rewardPaid[tokenId][token] = (weight * rewardPerWeight[token]) / PRECISION;
    }
  }

  function _harvestAll(uint256 tokenId, address to) private {
    uint256 n = rewardTokens.length;
    for (uint256 i; i < n; ++i) {
      _harvest(tokenId, rewardTokens[i], to);
    }
  }

  function _harvest(uint256 tokenId, address token, address to) private returns (uint256 amount) {
    BeehiveTypes.Stake memory s = _stakes[tokenId];
    uint256 accum = (s.weight * rewardPerWeight[token]) / PRECISION;
    uint256 already = rewardPaid[tokenId][token];
    uint256 extra = accum > already ? accum - already : 0;
    amount = accrued[tokenId][token] + extra;
    rewardPaid[tokenId][token] = accum;
    accrued[tokenId][token] = 0;
    if (amount > 0) {
      IERC20(token).safeTransfer(to, amount);
      emit RewardClaimed(tokenId, token, to, amount);
    }
  }

  function _u(uint256 v) private pure returns (string memory) {
    if (v == 0) return "0";
    uint256 j = v;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory b = new bytes(len);
    while (v != 0) {
      len--;
      b[len] = bytes1(uint8(48 + (v % 10)));
      v /= 10;
    }
    return string(b);
  }
}

interface HoneyPotView {
  function epochStart() external view returns (uint64);
}

interface HoneyPotHook {
  function noteLock(uint256 tokenId, uint256 weight) external;
  function noteUnlock(uint256 tokenId, uint256 weight, bool existedAtEpochStart) external;
  function settleOnUnlock(uint256 tokenId, address to) external;
}
