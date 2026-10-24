// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

/// @notice Fixed-cap DUES. Genesis mints the supply, then minting is permanently disabled.
contract DuesToken is ERC20, Ownable {
  uint256 public immutable maxSupply;
  uint8 private immutable _tokenDecimals;
  address public minter;
  bool public mintingEnabled;

  event MinterUpdated(address indexed minter);
  event MintingPermanentlyDisabled();

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 maxSupply_,
    address initialOwner
  ) ERC20(name_, symbol_) Ownable(initialOwner) {
    if (initialOwner == address(0)) revert BeehiveErrors.ZeroAddress();
    if (maxSupply_ == 0) revert BeehiveErrors.ZeroAmount();
    _tokenDecimals = decimals_;
    maxSupply = maxSupply_;
    mintingEnabled = true;
  }

  function decimals() public view override returns (uint8) {
    return _tokenDecimals;
  }

  function setMinter(address minter_) external onlyOwner {
    if (minter_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (!mintingEnabled) revert BeehiveErrors.MintingDisabled();
    minter = minter_;
    emit MinterUpdated(minter_);
  }

  function mint(address to, uint256 amount) external {
    if (!mintingEnabled) revert BeehiveErrors.MintingDisabled();
    if (msg.sender != minter) revert BeehiveErrors.Unauthorized();
    if (to == address(0)) revert BeehiveErrors.ZeroAddress();
    if (amount == 0) revert BeehiveErrors.ZeroAmount();
    if (totalSupply() + amount > maxSupply) revert BeehiveErrors.ExceedsMaxSupply();
    _mint(to, amount);
  }

  /// @notice Irreversible. After genesis this is the only legal mint state.
  function disableMinting() external {
    if (msg.sender != minter && msg.sender != owner()) revert BeehiveErrors.Unauthorized();
    if (!mintingEnabled) revert BeehiveErrors.MintingAlreadyDisabled();
    mintingEnabled = false;
    minter = address(0);
    emit MintingPermanentlyDisabled();
  }
}
