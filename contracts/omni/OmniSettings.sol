// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

interface ILzSetPeer {
  function setPeer(uint32 eid, bytes32 peer) external;
}

/// @notice Config-driven LayerZero book plus optional forwarding to OFT/ONFT wrappers.
contract OmniSettings is Ownable {
  struct Peer {
    uint32 eid;
    bytes32 peer;
  }

  address public endpoint;
  uint32 public localEid;
  bool public enabled;
  address public oft;
  address public onft;
  Peer[] public peers;

  event Configured(address endpoint, uint32 localEid, bool enabled);
  event PeerSet(uint32 indexed eid, bytes32 peer);
  event WrappersUpdated(address oft, address onft);
  event WrapperPeerForwarded(address indexed wrapper, uint32 indexed eid, bytes32 peer);

  constructor(address owner_, address endpoint_, uint32 localEid_, bool enabled_) Ownable(owner_) {
    if (owner_ == address(0)) revert BeehiveErrors.ZeroAddress();
    if (enabled_ && (endpoint_ == address(0) || localEid_ == 0)) revert BeehiveErrors.InvalidConfig("layerzero");
    endpoint = endpoint_;
    localEid = localEid_;
    enabled = enabled_;
    emit Configured(endpoint_, localEid_, enabled_);
  }

  function setEnabled(bool enabled_, address endpoint_, uint32 localEid_) external onlyOwner {
    if (enabled_ && (endpoint_ == address(0) || localEid_ == 0)) revert BeehiveErrors.InvalidConfig("layerzero");
    enabled = enabled_;
    endpoint = endpoint_;
    localEid = localEid_;
    emit Configured(endpoint_, localEid_, enabled_);
  }

  function setWrappers(address oft_, address onft_) external onlyOwner {
    oft = oft_;
    onft = onft_;
    emit WrappersUpdated(oft_, onft_);
    uint256 n = peers.length;
    for (uint256 i; i < n; ++i) {
      _forward(oft_, peers[i].eid, peers[i].peer);
      _forward(onft_, peers[i].eid, peers[i].peer);
    }
  }

  function setPeer(uint32 eid, bytes32 peer) external onlyOwner {
    if (!enabled) revert BeehiveErrors.NotInitialized();
    if (eid == 0 || eid == localEid) revert BeehiveErrors.InvalidConfig("peer.eid");
    if (peer == bytes32(0)) revert BeehiveErrors.ZeroAddress();
    uint256 n = peers.length;
    for (uint256 i; i < n; ++i) {
      if (peers[i].eid == eid) {
        peers[i].peer = peer;
        emit PeerSet(eid, peer);
        _forward(oft, eid, peer);
        _forward(onft, eid, peer);
        return;
      }
    }
    peers.push(Peer({eid: eid, peer: peer}));
    emit PeerSet(eid, peer);
    _forward(oft, eid, peer);
    _forward(onft, eid, peer);
  }

  function peerCount() external view returns (uint256) {
    return peers.length;
  }

  function _forward(address wrapper, uint32 eid, bytes32 peer) private {
    if (wrapper == address(0)) return;
    ILzSetPeer(wrapper).setPeer(eid, peer);
    emit WrapperPeerForwarded(wrapper, eid, peer);
  }
}
