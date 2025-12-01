// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OFTDUES is ERC20, Ownable {
  mapping(uint => address) public peers;
  event PeerSet(uint chainId, address peer);
  event Send(uint dstChainId, address to, uint amount, bytes options, uint fee);

  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {}

  function setPeer(uint chainId, address peer) external onlyOwner {
    peers[chainId] = peer;
    emit PeerSet(chainId, peer);
  }

  function quote(uint dstChainId, bytes calldata payload, bytes calldata options) external pure returns (uint) {
    return 0;
  }

  function send(uint dstChainId, address to, uint amount, bytes calldata options) external payable {
    _burn(msg.sender, amount);
    emit Send(dstChainId, to, amount, options, msg.value);
  }

  function mint(address to, uint amount) external onlyOwner {
    _mint(to, amount);
  }
}