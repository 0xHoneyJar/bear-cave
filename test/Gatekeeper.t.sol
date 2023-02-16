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
    bytes32[] private allowListData; // TODO: do i need this?

    address[] private gate1Users;
    address[] private gate2Users;

    MockERC721 private honeyComb;
    MockERC1155 private mockBear;

    function createNode(address player, uint32 amount) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(player, amount));
    }

    function createAllowNode(address player) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(player));
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
            allowListData.push(keccak256(abi.encodePacked(gate1Users[i])));
        }
        for (uint8 i = 0; i < gate2Users.length; ++i) {
            data2[i] = createNode(gate2Users[i], i);
            allowListData.push(keccak256(abi.encodePacked(gate2Users[i])));
        }

        bytes32 root1 = merkleLib.getRoot(data1);
        bytes32 root2 = merkleLib.getRoot(data2);

        gatekeeper = new Gatekeeper(address(gameRegistry));

        gatekeeper.addGate(TOKENID, root1, MAX_CLAIMABLE);
        gatekeeper.addGate(TOKENID, root2, MAX_CLAIMABLE);
    }

    function testAddingGates() public {
        (bool active, , uint32 maxClaimable, ) = gatekeeper.tokenToGates(TOKENID, 0);
        assertEq(maxClaimable, MAX_CLAIMABLE);
        assertEq(active, true);
    }

    function testClaim() public {
        gameRegistry.registerGame(address(this));

        uint32 userIdx = 5; // also the amount to claim
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];

        bytes32[] memory proof = getProof1(userIdx);
        uint32 claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, userIdx);
        gatekeeper.addClaimed(TOKENID, gateIdx, userIdx);

        // hit the max
        userIdx = 10;
        proof = getProof1(userIdx);
        player = gate1Users[userIdx];
        claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, MAX_CLAIMABLE - 5); // 5 is the orinal claimed
    }

    function testClaim_onlyMax() public {
        uint32 userIdx = MAX_CLAIMABLE + 1;
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];

        bytes32[] memory proof = getProof1(userIdx);
        uint32 claimedAmount = gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
        assertEq(claimedAmount, MAX_CLAIMABLE);
    }

    function testFailNoPermissions() public {
        gatekeeper.addClaimed(TOKENID, 69, MAX_CLAIMABLE + 1);
    }

    function testFailNoMoreLeft() public {
        uint32 userIdx = 5; // also the amount to claim
        uint32 gateIdx = 0;
        address player = gate1Users[userIdx];
        gameRegistry.registerGame(address(this));
        gatekeeper.addClaimed(TOKENID, gateIdx, MAX_CLAIMABLE + 1);

        bytes32[] memory proof = getProof1(userIdx);
        gatekeeper.claim(TOKENID, gateIdx, player, userIdx, proof);
    }
}
