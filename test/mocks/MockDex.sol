// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockPair is ERC20 {
  address public token0;
  address public token1;
  uint112 public reserve0;
  uint112 public reserve1;
  uint32 public blockTimestampLast;
  uint256 public price0CumulativeLast;
  uint256 public price1CumulativeLast;

  constructor() ERC20("Beehive LP", "HIVE-LP") {}

  function initialize(address tokenA, address tokenB) external {
    require(token0 == address(0), "init");
    token0 = tokenA;
    token1 = tokenB;
  }

  function getReserves() external view returns (uint112, uint112, uint32) {
    return (reserve0, reserve1, blockTimestampLast);
  }

  function sync() external {
    _update();
  }

  function mintTo(address to, uint256 amount) external {
    _update();
    _mint(to, amount);
  }

  function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
    if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
    if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);
    _update();
  }

  function _update() internal {
    uint32 t = uint32(block.timestamp);
    uint32 dt = blockTimestampLast == 0 ? 0 : t - blockTimestampLast;
    if (dt > 0 && reserve0 > 0 && reserve1 > 0) {
      price0CumulativeLast += ((uint256(reserve1) * (2 ** 112)) / uint256(reserve0)) * uint256(dt);
      price1CumulativeLast += ((uint256(reserve0) * (2 ** 112)) / uint256(reserve1)) * uint256(dt);
    }
    reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
    reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
    blockTimestampLast = t;
  }
}

contract MockFactory {
  mapping(address => mapping(address => address)) public getPair;
  address[] public allPairs;

  function createPair(address tokenA, address tokenB) external returns (address pair) {
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    MockPair deployed = new MockPair{salt: salt}();
    deployed.initialize(token0, token1);
    pair = address(deployed);
    getPair[token0][token1] = pair;
    getPair[token1][token0] = pair;
    allPairs.push(pair);
  }
}

contract MockRouter {
  MockFactory public immutable factory;

  constructor(address factory_) {
    factory = MockFactory(factory_);
  }

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256,
    uint256,
    address to,
    uint256
  ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
    address pair = factory.getPair(tokenA, tokenB);
    if (pair == address(0)) pair = factory.createPair(tokenA, tokenB);
    IERC20(tokenA).transferFrom(msg.sender, pair, amountADesired);
    IERC20(tokenB).transferFrom(msg.sender, pair, amountBDesired);
    liquidity = _sqrt(amountADesired * amountBDesired);
    if (liquidity == 0) liquidity = 1;
    MockPair(pair).mintTo(to, liquidity);
    return (amountADesired, amountBDesired, liquidity);
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256
  ) external returns (uint256[] memory amounts) {
    address pair = factory.getPair(path[0], path[1]);
    require(pair != address(0), "pair");
    MockPair p = MockPair(pair);
    (uint112 r0, uint112 r1,) = p.getReserves();
    bool zin = path[0] == p.token0();
    uint256 reserveIn = zin ? uint256(r0) : uint256(r1);
    uint256 reserveOut = zin ? uint256(r1) : uint256(r0);
    uint256 amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997);
    require(amountOut >= amountOutMin, "slip");
    IERC20(path[0]).transferFrom(msg.sender, pair, amountIn);
    if (zin) p.swap(0, amountOut, to);
    else p.swap(amountOut, 0, to);
    amounts = new uint256[](2);
    amounts[0] = amountIn;
    amounts[1] = amountOut;
  }

  function _sqrt(uint256 y) private pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }
}
