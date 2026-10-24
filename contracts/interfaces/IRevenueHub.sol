// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BeehiveTypes} from "contracts/BeehiveTypes.sol";

interface IRevenueHub {
  function onInflow(BeehiveTypes.RevenueSource source, address token, uint256 amount) external;
  function notify(BeehiveTypes.RevenueSource source, address token, uint256 amount) external;
}
