//SPDX-License-Identifier:MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.7;

contract Wildcard is ERC721, Ownable {
  mapping(address => bool) public acceptedTokens;

  uint256 public price = 33 ether;
  address public treasury = 0x81E0cCB4cB547b9551835Be01340508138695999;

  event TreasuryUpdated(address treasury);
  event PriceUpdated(uint256 price);
  event TokenAllowed(address token, bool allowed);

  constructor() ERC721("Lodge Wildcard", "LWC") {
    // default accepted tokens (BSC mainnet)
    acceptedTokens[0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56] = true; // BUSD
    acceptedTokens[0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3] = true; // DAI
    acceptedTokens[0x55d398326f99059fF775485246999027B3197955] = true; // USDT
    acceptedTokens[0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d] = true; // USDC
  }

  string public constant TOKEN_URI = "WILDCARD";
  uint256 private s_tokenCounter;

  function bulkMintNFT(
    uint256 _quantity,
    IERC20 token
  ) public returns (uint256) {
    require(acceptedTokens[address(token)], "Token Not Accepted");
    require(_quantity > 0, "Invalid quantity");
    require(
      IERC20(token).balanceOf(msg.sender) >= _quantity * price,
      "Not enough tokens"
    );
    require(
      IERC20(token).allowance(msg.sender, address(this)) >= _quantity * price,
      "Allowance Required"
    );
    require(
      IERC20(token).transferFrom(msg.sender, treasury, _quantity * price),
      "transfer failed"
    );
    for (uint256 i = 0; i < _quantity; i++) {
      _safeMint(msg.sender, s_tokenCounter);
      s_tokenCounter = s_tokenCounter + 1;
    }
    return s_tokenCounter;
  }

  function ownerMint(uint256 _quantity) public onlyOwner returns (uint256) {
    for (uint256 i = 0; i < _quantity; i++) {
      _safeMint(msg.sender, s_tokenCounter);
      s_tokenCounter = s_tokenCounter + 1;
    }
    return s_tokenCounter;
  }

  function tokenURI(
    uint256 /*tokenId*/
  ) public view override returns (string memory) {
    return TOKEN_URI;
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }

  function setTreasury(address _treasury) external onlyOwner {
    require(_treasury != address(0), "zero address");
    treasury = _treasury;
    emit TreasuryUpdated(_treasury);
  }

  function setPrice(uint256 _price) external onlyOwner {
    require(_price > 0, "invalid price");
    price = _price;
    emit PriceUpdated(_price);
  }

  function setTokenAllowed(address _token, bool _allowed) external onlyOwner {
    acceptedTokens[_token] = _allowed;
    emit TokenAllowed(_token, _allowed);
  }
}