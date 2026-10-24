// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.17;

contract ContractGuard {
    mapping(uint256 => mapping(address => bool)) private _status;

    function checkSameSenderReentranted() internal view returns (bool) {
        return _status[block.number][msg.sender];
    }

    modifier onlyOneBlock() {
        require(!checkSameSenderReentranted(), "ContractGuard: one block, one function");
        _;
        _status[block.number][msg.sender] = true;
    }
}