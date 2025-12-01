// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBeehiveEscrow} from "contracts/interfaces/IBeehiveEscrow.sol";

contract Loans {
  IBeehiveEscrow public immutable escrow;
  IERC20 public immutable dues;
  uint256 public immutable ltvBps; // e.g., 3000 = 30%

  struct Collateral {
    address owner;
    uint256 debt;
  }

  mapping(uint256 => Collateral) public collateral;

  event Funded(address indexed provider, uint256 amount);
  event Borrowed(uint256 indexed tokenId, address indexed owner, uint256 amount);
  event Repaid(uint256 indexed tokenId, address indexed owner, uint256 amount);
  event Liquidated(uint256 indexed tokenId, address indexed liquidator, uint256 repaid);

  constructor(address _escrow, uint256 _ltvBps) {
    escrow = IBeehiveEscrow(_escrow);
    dues = IERC20(escrow.token());
    ltvBps = _ltvBps;
  }

  function fund(uint256 amount) external {
    require(amount > 0, "amount=0");
    require(dues.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
    emit Funded(msg.sender, amount);
  }

  function ownerOf(uint256 tokenId) public view returns (address) {
    return escrow.ownerOf(tokenId);
  }

  function maxBorrow(uint256 tokenId) public view returns (uint256) {
    uint256 power = escrow.balanceOfNFT(tokenId);
    return (power * ltvBps) / 10000;
  }

  function lockedEnd(uint256 tokenId) public view returns (uint256) {
    return escrow.locked__end(tokenId);
  }

  function healthFactor(uint256 tokenId) public view returns (int256) {
    uint256 mb = maxBorrow(tokenId);
    uint256 d = collateral[tokenId].debt;
    return int256(mb) - int256(d);
  }

  function isCollateralized(uint256 tokenId) public view returns (bool) {
    return collateral[tokenId].debt > 0;
  }

  function borrow(uint256 tokenId, uint256 amount) external {
    require(amount > 0, "amount=0");
    address owner = escrow.ownerOf(tokenId);
    require(owner == msg.sender, "not owner");
    require(escrow.isApprovedOrOwner(address(this), tokenId), "approve Loans for NFT");
    // Move NFT collateral to Loans
    escrow.transferFrom(msg.sender, address(this), tokenId);

    uint256 mb = maxBorrow(tokenId);
    require(amount <= mb, "exceeds LTV");
    require(dues.balanceOf(address(this)) >= amount, "insufficient liquidity");

    Collateral storage c = collateral[tokenId];
    c.owner = owner;
    c.debt += amount;

    require(dues.transfer(owner, amount), "transfer failed");
    emit Borrowed(tokenId, owner, amount);
  }

  function repay(uint256 tokenId, uint256 amount) external {
    require(amount > 0, "amount=0");
    Collateral storage c = collateral[tokenId];
    require(c.owner == msg.sender, "not borrower");
    require(c.debt >= amount, "amount > debt");
    require(dues.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
    c.debt -= amount;
    emit Repaid(tokenId, msg.sender, amount);
    if (c.debt == 0) {
      // Return NFT to owner
      escrow.transferFrom(address(this), c.owner, tokenId);
    }
  }

  // Liquidator pays the outstanding debt and receives the NFT
  function liquidate(uint256 tokenId, uint256 repayAmount, address to) external {
    Collateral storage c = collateral[tokenId];
    require(c.debt > 0, "no debt");
    // Require undercollateralized or lock expired
    bool expired = block.timestamp >= escrow.locked__end(tokenId);
    bool undercollateralized = maxBorrow(tokenId) < c.debt;
    require(expired || undercollateralized, "not eligible");
    require(repayAmount >= c.debt, "repay < debt");
    require(dues.transferFrom(msg.sender, address(this), repayAmount), "transferFrom failed");
    // Clear debt and transfer NFT; will revert if attached/voted
    c.debt = 0;
    escrow.transferFrom(address(this), to, tokenId);
    emit Liquidated(tokenId, msg.sender, repayAmount);
  }
}