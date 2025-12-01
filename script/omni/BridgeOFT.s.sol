// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {OFTDUES} from "contracts/omni/OFTDUES.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

contract BridgeOFT is Script {
  function run(address oft, uint32 dstEid, address to, uint256 amount, bytes calldata extraOptions) external payable {
    vm.startBroadcast();
    SendParam memory p = SendParam({
      dstEid: dstEid,
      to: bytes32(uint256(uint160(to))),
      amountLD: amount,
      minAmountLD: 0,
      extraOptions: extraOptions,
      composeMsg: bytes("") ,
      oftCmd: bytes("")
    });
    MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});
    OFTDUES(oft).send(p, fee, msg.sender);
    vm.stopBroadcast();
  }
}