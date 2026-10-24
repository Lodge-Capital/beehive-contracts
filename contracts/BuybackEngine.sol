// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {IUniswapV2Router02} from "contracts/interfaces/IUniswapV2Router02.sol";

/// @notice Spends the buyback share of quote inflows to buy DUES and lock it as protocol LP.
contract BuybackEngine is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IERC20 public immutable dues;
  IERC20 public immutable quote;
  IUniswapV2Router02 public router;
  address public lpToken;
  uint16 public slippageBps;
  uint256 public lockedLiquidity;

  event RouterUpdated(address router, address lpToken);
  event BuybackExecuted(uint256 quoteSpent, uint256 duesBought, uint256 lpLocked);
  event SlippageUpdated(uint16 slippageBps);

  constructor(address dues_, address quote_, address owner_, uint16 slippageBps_) Ownable(owner_) {
    if (dues_ == address(0) || quote_ == address(0) || owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (slippageBps_ > 2_000) revert BeehiveErrors.OutOfBounds();
    dues = IERC20(dues_);
    quote = IERC20(quote_);
    slippageBps = slippageBps_;
  }

  function setRouter(address router_, address lpToken_) external onlyOwner {
    if (router_ == address(0) || lpToken_ == address(0)) revert BeehiveErrors.ZeroAddress();
    router = IUniswapV2Router02(router_);
    lpToken = lpToken_;
    emit RouterUpdated(router_, lpToken_);
  }

  function setSlippageBps(uint16 slippageBps_) external onlyOwner {
    if (slippageBps_ > 2_000) revert BeehiveErrors.OutOfBounds();
    slippageBps = slippageBps_;
    emit SlippageUpdated(slippageBps_);
  }

  function execute(uint256 quoteAmount) external nonReentrant {
    if (address(router) == address(0)) revert BeehiveErrors.NotInitialized();
    uint256 bal = quote.balanceOf(address(this));
    if (quoteAmount == 0 || quoteAmount > bal) quoteAmount = bal;
    if (quoteAmount < 2) revert BeehiveErrors.ZeroAmount();

    uint256 swapIn = quoteAmount / 2;
    uint256 rest = quoteAmount - swapIn;
    address[] memory path = new address[](2);
    path[0] = address(quote);
    path[1] = address(dues);

    uint256 duesBefore = dues.balanceOf(address(this));
    quote.forceApprove(address(router), quoteAmount);
    router.swapExactTokensForTokens(swapIn, 0, path, address(this), block.timestamp);
    uint256 duesBought = dues.balanceOf(address(this)) - duesBefore;
    if (duesBought == 0) revert BeehiveErrors.ZeroAmount();

    dues.forceApprove(address(router), duesBought);
    (,, uint256 liq) = router.addLiquidity(
      address(dues), address(quote), duesBought, rest, 0, 0, address(this), block.timestamp
    );
    lockedLiquidity += liq;
    emit BuybackExecuted(quoteAmount, duesBought, liq);
  }
}
