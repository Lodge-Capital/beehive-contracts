// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ONFTLock is ERC721, Ownable {
  mapping(uint => address) public peers;
  event PeerSet(uint chainId, address peer);
  event Send(uint dstChainId, address to, uint tokenId, bytes options, uint fee);

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

  function setPeer(uint chainId, address peer) external onlyOwner {
    peers[chainId] = peer;
    emit PeerSet(chainId, peer);
  }

  function quote(uint dstChainId, bytes calldata payload, bytes calldata options) external pure returns (uint) {
    return 0;
  }

  function send(uint dstChainId, address to, uint tokenId, bytes calldata options) external payable {
    require(ownerOf(tokenId) == msg.sender, "not owner");
    emit Send(dstChainId, to, tokenId, options, msg.value);
  }

  function mint(address to, uint tokenId) external onlyOwner {
    _mint(to, tokenId);
  }

  function burn(uint tokenId) external onlyOwner {
    _burn(tokenId);
  }
}