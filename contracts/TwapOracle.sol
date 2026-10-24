// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";
import {IUniswapV2Pair} from "contracts/interfaces/IUniswapV2Pair.sol";

/// @notice Config-driven TWAP of the DUES/quote pair, used for LP valuation (loans + market).
contract TwapOracle is Ownable {
  struct Observation {
    uint32 timestamp;
    uint256 price0Cumulative;
    uint256 price1Cumulative;
  }

  IUniswapV2Pair public immutable pair;
  address public immutable dues;
  address public immutable quote;
  bool public immutable duesIsToken0;
  uint8 public immutable duesDecimals;
  uint32 public window;
  uint256 public minLiquidity;

  Observation[] public observations;

  event Updated(uint32 timestamp, uint256 price0Cumulative, uint256 price1Cumulative);
  event WindowUpdated(uint32 window);
  event MinLiquidityUpdated(uint256 minLiquidity);

  constructor(address pair_, address dues_, address quote_, address owner_, uint32 window_, uint256 minLiquidity_)
    Ownable(owner_)
  {
    if (pair_ == address(0) || dues_ == address(0) || quote_ == address(0) || owner_ == address(0)) {
      revert BeehiveErrors.ZeroAddress();
    }
    if (window_ < 60 || window_ > 1 days) revert BeehiveErrors.OutOfBounds();
    pair = IUniswapV2Pair(pair_);
    dues = dues_;
    quote = quote_;
    // Uniswap V2 sorts token0 < token1. Pair may not exist yet at launch time.
    duesIsToken0 = dues_ < quote_;
    duesDecimals = IERC20Metadata(dues_).decimals();
    window = window_;
    minLiquidity = minLiquidity_;
  }

  function setWindow(uint32 window_) external onlyOwner {
    if (window_ < 60 || window_ > 1 days) revert BeehiveErrors.OutOfBounds();
    window = window_;
    emit WindowUpdated(window_);
  }

  function setMinLiquidity(uint256 minLiquidity_) external onlyOwner {
    minLiquidity = minLiquidity_;
    emit MinLiquidityUpdated(minLiquidity_);
  }

  function ready() public view returns (bool) {
    uint256 n = observations.length;
    if (n == 0) return false;
    return block.timestamp >= uint256(observations[0].timestamp) + uint256(window);
  }

  function update() external {
    pair.sync();
    (uint112 r0, uint112 r1,) = pair.getReserves();
    if (uint256(r0) + uint256(r1) < minLiquidity) revert BeehiveErrors.InsufficientReserves();
    Observation memory obs = Observation({
      timestamp: uint32(block.timestamp),
      price0Cumulative: pair.price0CumulativeLast(),
      price1Cumulative: pair.price1CumulativeLast()
    });
    observations.push(obs);
    emit Updated(obs.timestamp, obs.price0Cumulative, obs.price1Cumulative);
  }

  function consultLpValue(uint256 lpAmount) public view returns (uint256 quoteValue) {
    if (!ready()) revert BeehiveErrors.OracleNotReady();
    (uint112 r0, uint112 r1,) = pair.getReserves();
    uint256 supply = pair.totalSupply();
    if (supply == 0 || lpAmount == 0) return 0;
    uint256 duesReserve = duesIsToken0 ? uint256(r0) : uint256(r1);
    uint256 quoteReserve = duesIsToken0 ? uint256(r1) : uint256(r0);
    if (duesReserve < minLiquidity / 2 || quoteReserve < minLiquidity / 2) revert BeehiveErrors.InsufficientReserves();

    uint256 duesShare = (lpAmount * duesReserve) / supply;
    uint256 quoteShare = (lpAmount * quoteReserve) / supply;
    uint256 duesPrice = _twapDuesPerQuote(); // quote units per 1 dues token (duesDecimals)
    uint256 duesInQuote = (duesShare * duesPrice) / (10 ** uint256(duesDecimals));
    quoteValue = quoteShare + duesInQuote;
  }

  function _twapDuesPerQuote() internal view returns (uint256) {
    uint256 n = observations.length;
    Observation memory latest = observations[n - 1];
    Observation memory startObs = latest;
    uint32 target = latest.timestamp > window ? latest.timestamp - window : 0;
    for (uint256 i = n; i > 0; --i) {
      Observation memory o = observations[i - 1];
      startObs = o;
      if (o.timestamp <= target) break;
    }
    uint256 dt = uint256(latest.timestamp) - uint256(startObs.timestamp);
    if (dt == 0) revert BeehiveErrors.OracleNotReady();
    uint256 c0 = latest.price0Cumulative - startObs.price0Cumulative;
    uint256 c1 = latest.price1Cumulative - startObs.price1Cumulative;
    // Uniswap V2 cumulatives are UQ112x112. Decode to quote per 1 dues token.
    if (duesIsToken0) {
      return (c1 / dt) * (10 ** uint256(duesDecimals)) / 2 ** 112;
    }
    return (c0 / dt) * (10 ** uint256(duesDecimals)) / 2 ** 112;
  }
}
