// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library BeehiveTypes {
  enum RevenueSource {
    EarlySlash,
    LatePenalty,
    MarketplaceFee,
    LoanInterest,
    LodgeFiDeposit,
    ProtocolHook,
    GenesisProceeds
  }

  struct Stake {
    uint256 lpAmount;
    uint256 weight;
    uint64 start;
    uint64 end;
    uint64 unlockedAt;
  }

  struct Listing {
    address seller;
    uint256 ask;
    uint64 listedAt;
    bool active;
  }

  struct Loan {
    address borrower;
    uint256 principal;
    uint64 start;
    uint64 lastAccrual;
    bool open;
  }

  struct Auction {
    uint256 startPrice;
    uint256 endPrice;
    uint64 startTime;
    uint64 duration;
    bool active;
  }

  struct Epoch {
    uint64 start;
    uint64 end;
    uint256 pot;
    uint256 eligibleWeight;
    bool closed;
  }
}
