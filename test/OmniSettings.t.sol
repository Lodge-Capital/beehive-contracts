// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {OmniSettings} from "contracts/omni/OmniSettings.sol";
import {BeehiveErrors} from "contracts/BeehiveErrors.sol";

contract MockLzPeer {
  mapping(uint32 => bytes32) public peers;

  function setPeer(uint32 eid, bytes32 peer) external {
    peers[eid] = peer;
  }
}

contract OmniSettingsTest is Test {
  function testForwardsPeersToOptionalWrappers() public {
    MockLzPeer oft = new MockLzPeer();
    MockLzPeer onft = new MockLzPeer();
    OmniSettings omni = new OmniSettings(address(this), address(0xE), 30184, true);
    omni.setWrappers(address(oft), address(onft));
    bytes32 peer = bytes32(uint256(uint160(address(0xBEEF))));
    omni.setPeer(30110, peer);
    assertEq(oft.peers(30110), peer);
    assertEq(onft.peers(30110), peer);
    assertEq(omni.peerCount(), 1);
  }

  function testStoresPeersWithoutWrappers() public {
    OmniSettings omni = new OmniSettings(address(this), address(0xE), 30184, true);
    bytes32 peer = bytes32(uint256(uint160(address(0xBEEF))));
    omni.setPeer(30110, peer);
    (, bytes32 stored) = omni.peers(0);
    assertEq(stored, peer);
  }

  function testDisabledRejectsPeers() public {
    OmniSettings omni = new OmniSettings(address(this), address(0), 0, false);
    vm.expectRevert(BeehiveErrors.NotInitialized.selector);
    omni.setPeer(30110, bytes32(uint256(1)));
  }

  function testSetWrappersForwardsExistingPeers() public {
    MockLzPeer oft = new MockLzPeer();
    OmniSettings omni = new OmniSettings(address(this), address(0xE), 30184, true);
    bytes32 peer = bytes32(uint256(uint160(address(0xBEEF))));
    omni.setPeer(30110, peer);
    omni.setWrappers(address(oft), address(0));
    assertEq(oft.peers(30110), peer);
  }
}
