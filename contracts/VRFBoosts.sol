// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract VRFBoosts {
  address public admin;
  mapping(uint => uint) public dailyBoost; // dayStart => multiplier in 1e18 (e.g., 1.05e18)

  event AdminUpdated(address admin);
  event BoostSet(uint dayStart, uint multiplier);

  constructor(address _admin) {
    admin = _admin;
    emit AdminUpdated(_admin);
  }

  function setAdmin(address _admin) external {
    require(msg.sender == admin, "not admin");
    admin = _admin;
    emit AdminUpdated(_admin);
  }

  function setDailyBoost(uint dayStart, uint multiplier) external {
    require(msg.sender == admin, "not admin");
    dailyBoost[dayStart] = multiplier;
    emit BoostSet(dayStart, multiplier);
  }

  function currentBoost() external view returns (uint) {
    uint dayStart = (block.timestamp / 1 days) * 1 days;
    uint m = dailyBoost[dayStart];
    return m == 0 ? 1e18 : m;
  }
}