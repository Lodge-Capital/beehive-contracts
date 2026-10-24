// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

/// @notice Owner-controlled timelock for sensitive setters. Delay is bounded by config.
contract BeehiveTimelock is Ownable {
  struct Call {
    address target;
    bytes data;
    uint64 eta;
    bool executed;
    bool canceled;
  }

  uint256 public immutable minDelay;
  uint256 public immutable maxDelay;
  uint256 public delay;
  address public guardian;
  uint256 public nextId;
  mapping(uint256 => Call) public calls;

  event Queued(uint256 indexed id, address indexed target, bytes data, uint64 eta);
  event Executed(uint256 indexed id);
  event Canceled(uint256 indexed id);
  event DelayUpdated(uint256 delay);
  event GuardianUpdated(address guardian);

  constructor(address owner_, address guardian_, uint256 delay_, uint256 minDelay_, uint256 maxDelay_)
    Ownable(owner_)
  {
    if (owner_ == address(0) || guardian_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (minDelay_ == 0 || maxDelay_ < minDelay_ || delay_ < minDelay_ || delay_ > maxDelay_) {
      revert BeehiveErrors.OutOfBounds();
    }
    guardian = guardian_;
    delay = delay_;
    minDelay = minDelay_;
    maxDelay = maxDelay_;
  }

  function setDelay(uint256 delay_) external onlyOwner {
    if (delay_ < minDelay || delay_ > maxDelay) revert BeehiveErrors.OutOfBounds();
    delay = delay_;
    emit DelayUpdated(delay_);
  }

  function setGuardian(address guardian_) external onlyOwner {
    if (guardian_ == address(0)) revert BeehiveErrors.ZeroAddress();
    guardian = guardian_;
    emit GuardianUpdated(guardian_);
  }

  function queue(address target, bytes calldata data) external onlyOwner returns (uint256 id) {
    if (target == address(0)) revert BeehiveErrors.ZeroAddress();
    id = nextId++;
    uint64 eta = uint64(block.timestamp + delay);
    calls[id] = Call({target: target, data: data, eta: eta, executed: false, canceled: false});
    emit Queued(id, target, data, eta);
  }

  function cancel(uint256 id) external {
    if (msg.sender != owner() && msg.sender != guardian) revert BeehiveErrors.Unauthorized();
    Call storage c = calls[id];
    if (c.target == address(0)) revert BeehiveErrors.TimelockMissing();
    if (c.executed || c.canceled) revert BeehiveErrors.TimelockMissing();
    c.canceled = true;
    emit Canceled(id);
  }

  function execute(uint256 id) external {
    Call storage c = calls[id];
    if (c.target == address(0)) revert BeehiveErrors.TimelockMissing();
    if (c.executed || c.canceled) revert BeehiveErrors.TimelockMissing();
    if (block.timestamp < c.eta) revert BeehiveErrors.TimelockNotReady();
    // 14-day grace after eta so stale ops cannot linger forever
    if (block.timestamp > uint256(c.eta) + 14 days) revert BeehiveErrors.TimelockExpired();
    c.executed = true;
    (bool ok, bytes memory ret) = c.target.call(c.data);
    if (!ok) {
      assembly {
        revert(add(ret, 32), mload(ret))
      }
    }
    emit Executed(id);
  }
}
