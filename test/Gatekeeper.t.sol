// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "murky/Merkle.sol";

import "src/Gatekeeper.sol";
import {GameRegistry} from "src/GameRegistry.sol";

import "./mocks/MockERC1155.sol";
import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";
import "./utils/UserFactory.sol";

contract GateKeeperTest is Test, ERC1155TokenReceiver {
    uint32 private constant MAX_CLAIMABLE = 12;
    uint32 private constant TOKENID = 69;
    Merkle private merkleLib = new Merkle();
    UserFactory private userFactory = new UserFactory();

    Gatekeeper private gatekeeper;
    GameRegistry private gameRegistry;

    bytes32[] private data1;
    bytes32[] private data2;

    address[] private gate1Users;
    address[] private gate2Users;

    MockERC721 private honeyComb;
    MockERC1155 private mockBear;

    function createNode(address player, uint32 amount) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(player, amount));
    }

    function getProof1(uint256 idx) private view returns (bytes32[] memory) {
        return merkleLib.getProof(data1, idx);
    }

    function getProof2(uint256 idx) private view returns (bytes32[] memory) {
        return merkleLib.getProof(data2, idx);
    }

    function setUp() public {
        gate1Users = userFactory.create(15);
        gate2Users = userFactory.create(17);

        honeyComb = new MockERC721("honeycomb", "honeycomb");

        // Game Registry
        gameRegistry = new GameRegistry();

        // Building the merkle tree
        data1 = new bytes32[](gate1Users.length);
        data2 = new bytes32[](gate2Users.length);

        for (uint8 i = 0; i < gate1Users.length; ++i) {
            data1[i] = createNode(gate1Users[i], i);
        }
        for (uint8 i = 0; i < gate2Users.length; ++i) {
            data2[i] = createNode(gate2Users[i], i);
        }

        bytes32 root1 = merkleLib.getRoot(data1);
        bytes32 root2 = merkleLib.getRoot(data2);

        gatekeeper = new Gatekeeper(address(gameRegistry));

        gatekeeper.addGate(TOKENID, root1, MAX_CLAIMABLE, 0); // opens immediately
        gatekeeper.addGate(TOKENID, root2, MAX_CLAIMABLE, 1); // opens after first stage
    }

    function testFailAddingGates() public {
        gatekeeper.addGate(TOKENID, bytes32(""), MAX_CLAIMABLE, 14);
    }

    function testAddingGates() public {
        (bool active, , , uint32 maxClaimable, , ) = gatekeeper.tokenToGates(TOKENID, 0);
        assertEq(maxClaimable, MAX_CLAIMABLE);
        assertEq(active, false);
    }

    function testStartingGates() public {
        gameRegistry.registerGame(address(this));
        gatekeeper.startGatesForToken(TOKENID);
        (bool active, , , , , ) = gatekeeper.tokenToGates(TOKENID, 0);
        assertEq(active, true);

        (, , , , , uint256 activeAt) = gatekeeper.tokenToGates(TOKENID, 1);
        assertGt(activeAt, block.timestamp);
    }

    function testFail_NotStarted() public view {
        gatekeeper.claim(TOKENID, 1, address(0), 1, getProof1(1));
    }

    function testFail_NotActive() public {
        gatekeeper.setGateEnabled(TOKENID, 1, true);
        gatekeeper.claim(TOKENID, 1, address(0), 1, getProof1(1));
    }

    function testFailClaim_NotActiveYet() public {
        gameRegistry.registerGame(address(this));
        gatekeeper.startGatesForToken(TOKENID);
        uint32 gateIdx = 1;
        gatekeeper.claim(TOKENID, gateIdx, address(0), 1, getProof2(1));
    }

    function testClaim() public {
        gameRegistry.registerGame(address(this));
        gatekeeper.startGatesForToken(TOKENID);

        uint32 userIdx = 5; // also the amount to claim
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];

        bytes32[] memory proof = getProof1(userIdx);
        uint32 claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, userIdx);
        gatekeeper.addClaimed(TOKENID, gateIdx, userIdx, proof);

        // hit the max
        userIdx = 10;
        proof = getProof1(userIdx);
        player = gate1Users[userIdx];
        claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, MAX_CLAIMABLE - 5); // 5 is the original claimed
    }

    function testClaim_onlyMax() public {
        gameRegistry.registerGame(address(this));
        gatekeeper.startGatesForToken(TOKENID);

        uint32 userIdx = MAX_CLAIMABLE + 1;
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];

        bytes32[] memory proof = getProof1(userIdx);
        uint32 claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, MAX_CLAIMABLE);
    }

    function testClaim_alreadyClaimed() public {
        gameRegistry.registerGame(address(this));
        gatekeeper.startGatesForToken(TOKENID);

        uint32 userIdx = 5;
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];

        bytes32[] memory proof = getProof1(userIdx);
        uint32 claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, userIdx, "uwot");

        gatekeeper.addClaimed(TOKENID, gateIdx, userIdx, proof);
        claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, 0, "you shouldn't be able to claim anymore");
    }

    function testFailNoPermissions() public {
        bytes32[] memory proof = getProof1(1);

        gatekeeper.addClaimed(TOKENID, 69, MAX_CLAIMABLE + 1, proof);
    }

    function testNoMoreLeft() public {
        uint32 userIdx = 5; // also the amount to claim
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];
        gameRegistry.registerGame(address(this));
        bytes32[] memory proof = getProof1(userIdx);

        gatekeeper.addClaimed(TOKENID, gateIdx, MAX_CLAIMABLE + 1, proof);

        uint256 claimAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimAmount, 0);
    }
}
