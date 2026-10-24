// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ITwapOracle} from "contracts/interfaces/ITwapOracle.sol";

contract MockOracle is ITwapOracle {
  uint256 public valuePerLp = 2e18;
  bool public readyFlag = true;

  function set(uint256 valuePerLp_) external {
    valuePerLp = valuePerLp_;
  }

  function setReady(bool ready_) external {
    readyFlag = ready_;
  }

  function consultLpValue(uint256 lpAmount) external view returns (uint256) {
    return (lpAmount * valuePerLp) / 1e18;
  }

  function ready() external view returns (bool) {
    return readyFlag;
  }

  function update() external {}
}
