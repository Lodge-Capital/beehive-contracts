// SPDX-License-Identifier: None
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WildCard is
  ERC721,
  ERC721Enumerable,
  ERC721URIStorage,
  Pausable,
  Ownable
{
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;
  uint256 public batchSize;
  uint256 public maxMint = 0;
  uint256 public price;
  address public token;

  modifier allowedMint() {
    uint256 tokenId = _tokenIdCounter.current();
    require(tokenId < maxMint, "Max Quantity");
    _;
  }

  constructor() ERC721("WildCard", "LWC") {}

  function setPrice(uint256 _price) public onlyOwner {
    price = _price * (1 ether);
  }

  function setToken(address _token) public onlyOwner {
    token = _token;
  }

  function addBatch(uint256 batch) public onlyOwner {
    batchSize = batch;
    maxMint += batch;
  }

  function publicMint() public allowedMint {
    require(IERC20(token).balanceOf(msg.sender) >= price, "Not enough tokens");
    require(
      IERC20(token).allowance(msg.sender, address(this)) >= price,
      "Allowance Required"
    );
    IERC20(token).transferFrom(msg.sender, owner(), price);
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(msg.sender, tokenId);
    _setTokenURI(tokenId, Strings.toString(tokenId));
  }

  function ownerMint(address destination) public onlyOwner allowedMint {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(destination, tokenId);
    _setTokenURI(tokenId, Strings.toString(tokenId));
  }

  function _baseURI() internal pure override returns (string memory) {
    return "";
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function safeMint(address to, string memory uri) public onlyOwner {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  // The following functions are overrides required by Solidity.

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(
    uint256 tokenId
  ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}

contract Open is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  string[] private URIs;
  address public token;

  modifier allowedMint() {
    require(IERC721(token).balanceOf(msg.sender) > 0, "Not enough tokens");
    require(
      IERC721(token).isApprovedForAll(msg.sender, address(this)) == true,
      "Approval Required"
    );
    _;
  }

  constructor(address _token) ERC721("LodgeUtilityCard", "LUC") {
    token = _token;
  }

  function publicMint(uint ID) public allowedMint {
    require(
      IERC721(token).ownerOf(ID) == msg.sender,
      "You do not own the token"
    );
    uint256 tokenId = _tokenIdCounter.current();
    require(tokenId < URIs.length);
    IERC721(token).transferFrom(msg.sender, address(this), ID);
    _tokenIdCounter.increment();
    _safeMint(msg.sender, tokenId);
    _setTokenURI(tokenId, URIs[ID]);
  }

  function addBatch(string[] memory _URIs) public onlyOwner {
    for (uint i = 0; i < _URIs.length; i++) {
      URIs.push(_URIs[i]);
    }
  }

  function _baseURI() internal pure override returns (string memory) {
    return "";
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function safeMint(address to, string memory uri) public onlyOwner {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  // The following functions are overrides required by Solidity.

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(
    uint256 tokenId
  ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}

