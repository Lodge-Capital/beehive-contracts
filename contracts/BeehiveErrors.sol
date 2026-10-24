// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Shared custom errors. Access checks never use assert.
library BeehiveErrors {
  error ZeroAddress();
  error ZeroAmount();
  error Unauthorized();
  error MintingDisabled();
  error MintingAlreadyDisabled();
  error ExceedsMaxSupply();
  error GenesisClosed();
  error GenesisOpen();
  error GenesisAlreadyFinalized();
  error GenesisNotFinalized();
  error InvalidLockDuration();
  error NotStakeOwner();
  error StakeNotActive();
  error StakeStillLocked();
  error InvalidSplit();
  error OutOfBounds();
  error NotApprovedSource();
  error UnknownToken();
  error SelfTrade();
  error ListingTooFresh();
  error NotListed();
  error AlreadyListed();
  error InvalidAsk();
  error LoanOpen();
  error NoLoan();
  error ExceedsLTV();
  error InsufficientLiquidity();
  error NotLiquidatable();
  error AuctionNotActive();
  error AuctionActive();
  error BidTooLow();
  error OracleNotReady();
  error InsufficientReserves();
  error AlreadyInitialized();
  error NotInitialized();
  error InvalidConfig(string field);
  error DeployFailed();
  error InitFailed();
  error TimelockNotReady();
  error TimelockExpired();
  error TimelockExists();
  error TimelockMissing();
  error NothingToClaim();
  error EpochNotEnded();
  error EpochAlreadyClosed();
  error NotEligible();
  error AlreadyClaimed();
  error TransferBlocked();
  error TradingHaltForbidden();
  error WithdrawLimited();
  error DeadlineExpired();
}
