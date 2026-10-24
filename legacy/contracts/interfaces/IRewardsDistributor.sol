pragma solidity 0.8.13;

interface IRewardsDistributor {
  function checkpoint_token() external;

  function checkpoint_total_supply() external;

  function claim(uint _tokenId) external returns (uint);

  function notifyPenalty() external;

  function claim_many(uint[] memory _tokenIds) external returns (bool);
}
