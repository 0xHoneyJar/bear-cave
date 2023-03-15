// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./mocks/MockERC1155.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVRFCoordinator.sol";
import "./utils/UserFactory.sol";
import "./utils/Random.sol";

import "src/BearCave.sol";
import {HoneyComb} from "src/HoneyComb.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/GameLib.sol";

import {console2} from "forge-std/console2.sol";

// TODO: test bearCave claiming process
contract FullGameTest is Test, ERC1155TokenReceiver {
    using FixedPointMathLib for uint256;
    using Address for address;

    Merkle private merkleLib = new Merkle();

    uint256 private constant MINT_PRICE_ERC20 = 99 * 1e8;
    uint256 private constant MINT_PRICE_ETH = 99 * 1e6 * 1 gwei;

    // Scenario Setup
    uint32 private maxHoneycomb = 15;
    uint256 private honeycombShare = 2233 * 1e14; // In WAD (.2233)
    uint32 private maxClaimableHoneycomb = 6;

    // Gatekeeper
    bytes32[] private gateData;
    bytes32 private gateRoot;

    // Dependencies
    uint256 private bearId = 69;
    MockERC1155 private erc1155;
    MockERC20 private paymentToken;

    // Users
    address payable private beekeeper;
    address payable private jani;
    address private gameAdmin;
    address private alfaHunter; //0
    address private bera; // 1
    address private clown; // 2

    // Deployables
    GameRegistry private gameRegistry;
    BearCave private bearCave;
    IBearCave.MintConfig private mintConfig;
    HoneyComb private honeycomb;
    Gatekeeper private gatekeeper;

    //Chainlink setup
    MockVRFCoordinator private vrfCoordinator;
    uint96 private constant FUND_AMOUNT = 1 * 10**18;

    function createNode(address player, uint32 amount) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(player, amount));
    }

    function getProof(uint256 idx) private view returns (bytes32[] memory) {
        return merkleLib.getProof(gateData, idx);
    }

    // Initialize the test suite
    function setUp() public {
        // Pre-req
        erc1155 = new MockERC1155();
        paymentToken = new MockERC20("OHM", "OHM", 9);

        //Users
        beekeeper = payable(makeAddr("beekeeper"));
        jani = payable(makeAddr("definitelyNotJani"));
        gameAdmin = makeAddr("gameAdmin");
        alfaHunter = makeAddr("alfaHunter");
        bera = makeAddr("bera");
        clown = makeAddr("clown");

        console2.log("beekeeper: ", beekeeper);
        console2.log("jani: ", jani);
        console2.log("gameAdmin: ", gameAdmin);
        console2.log("alfaHunter: ", alfaHunter);
        console2.log("bera: ", bera);
        console2.log("clown: ", clown);
        console2.log("deployer: ", address(this));

        // Mint a bear to the gameAdmin
        erc1155.mint(gameAdmin, bearId, 1, "");

        paymentToken.mint(alfaHunter, MINT_PRICE_ERC20 * 100);
        paymentToken.mint(bera, MINT_PRICE_ERC20 * 100);
        paymentToken.mint(clown, MINT_PRICE_ERC20 * 100);

        // Chainlink setup
        vrfCoordinator = new MockVRFCoordinator();
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        /**
         * Deploy contracts
         */
        gameRegistry = new GameRegistry();
        // Transfer gameAdmin to real Admin
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        honeycomb = new HoneyComb(address(gameRegistry));
        gatekeeper = new Gatekeeper(address(gameRegistry));

        bearCave = new BearCave(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeycomb),
            address(erc1155),
            address(paymentToken),
            address(gatekeeper),
            honeycombShare
        );

        bearCave.setJani(jani);
        bearCave.setBeeKeeper(beekeeper);

        mintConfig = IBearCave.MintConfig({
            maxHoneycomb: maxHoneycomb,
            maxClaimableHoneycomb: maxClaimableHoneycomb,
            honeycombPrice_ERC20: MINT_PRICE_ERC20, // 9.9 OHM
            honeycombPrice_ETH: MINT_PRICE_ETH // 0.099 eth
        });

        // Set up on VRF site
        vrfCoordinator.addConsumer(subId, address(bearCave));
        bearCave.initialize("", subId, mintConfig);
        gameRegistry.registerGame(address(bearCave));

        /**
         *   Generate roots
         */
        gateData = new bytes32[](3);
        gateData[0] = createNode(alfaHunter, 2);
        gateData[1] = createNode(bera, 3);
        gateData[2] = createNode(clown, 3);
        gateRoot = merkleLib.getRoot(gateData);
        gatekeeper.addGate(bearId, gateRoot, maxClaimableHoneycomb + 1, 0);

        // Deployer doesn't have any perms after setup
        gameRegistry.renounceRole(Constants.GAME_ADMIN, address(this));
    }

    function testWorks() public {
        assertTrue(true);
    }

    function testFullRun() public {
        // Game Admin Actions
        vm.startPrank(gameAdmin);
        gameRegistry.startGame(address(bearCave));
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        vm.stopPrank();

        // Get the first gate for validation
        (
            bool enabled,
            uint8 stageIndex,
            uint32 claimedCount,
            uint32 maxClaimable,
            bytes32 _gateRoot,
            uint256 activeAt
        ) = gatekeeper.tokenToGates(bearId, 0);

        assertTrue(enabled);
        assertEq(stageIndex, 0);
        assertEq(claimedCount, 0);
        assertEq(maxClaimable, maxClaimableHoneycomb + 1);
        assertEq(_gateRoot, gateRoot);
        assertEq(activeAt, block.timestamp); // should be active now.

        /**
            Phase 1: claim available
         */

        assertEq(gatekeeper.claim(bearId, 0, alfaHunter, 2, getProof(0)), 2);
        vm.startPrank(alfaHunter);
        bearCave.claim(bearId, 0, 2, getProof(0));
        assertEq(honeycomb.balanceOf(alfaHunter), 2);
        vm.stopPrank();

        vm.startPrank(bera);
        bearCave.claim(bearId, 0, 3, getProof(1));
        assertEq(honeycomb.balanceOf(bera), 3);
        vm.stopPrank();

        vm.startPrank(clown);
        bearCave.claim(bearId, 0, 3, getProof(2));
        assertEq(honeycomb.balanceOf(clown), 1);
        vm.stopPrank();

        // Gate claimable is > game claimable.
        // Game claimable clamps number of allowed mints.
        assertEq(bearCave.claimed(bearId), 6);
        (, , claimedCount, maxClaimable, , ) = gatekeeper.tokenToGates(bearId, 0);
        assertEq(claimedCount, 6);
        assertEq(maxClaimable, 7);

        /**
            Phase 2: do it again:
            Do it again, and validate nothing changes.
         */

        vm.startPrank(alfaHunter);
        bearCave.claim(bearId, 0, 2, getProof(0));
        assertEq(honeycomb.balanceOf(alfaHunter), 2);
        vm.stopPrank();

        vm.startPrank(bera);
        bearCave.claim(bearId, 0, 3, getProof(1));
        assertEq(honeycomb.balanceOf(bera), 3);
        vm.stopPrank();

        vm.startPrank(clown);
        bearCave.claim(bearId, 0, 3, getProof(2));
        assertEq(honeycomb.balanceOf(clown), 1);
        vm.stopPrank();
        /**
            Phase 3: early mint 
         */

        // TODO validate jani/beekeeper balances

        vm.startPrank(alfaHunter);
        paymentToken.approve(address(bearCave), 2 * MINT_PRICE_ERC20);
        bearCave.earlyMekHoneyCombWithERC20(bearId, 0, 2, getProof(0), 1);
        assertEq(honeycomb.balanceOf(alfaHunter), 3);
        vm.stopPrank();

        vm.startPrank(bera);
        paymentToken.approve(address(bearCave), 3 * MINT_PRICE_ERC20);
        bearCave.earlyMekHoneyCombWithERC20(bearId, 0, 3, getProof(1), 2);
        assertEq(honeycomb.balanceOf(bera), 5); //claimed 3, early minted 2
        vm.stopPrank();

        vm.startPrank(clown);
        paymentToken.approve(address(bearCave), 3 * MINT_PRICE_ERC20);
        bearCave.earlyMekHoneyCombWithERC20(bearId, 0, 3, getProof(2), 2);
        assertEq(honeycomb.balanceOf(clown), 3); // claimed 1, earlyMinted 2
        vm.stopPrank();

        /**
            Phase 4: general Mint
         */
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(bera);
        paymentToken.approve(address(bearCave), 3 * MINT_PRICE_ERC20);
        bearCave.mekHoneyCombWithERC20(bearId, 3);
        assertEq(honeycomb.balanceOf(bera), 3 + 2 + 3); //claimed 3, early minted 2, mint 3
        vm.stopPrank();

        vm.startPrank(clown);
        paymentToken.approve(address(bearCave), 2 * MINT_PRICE_ERC20);
        bearCave.mekHoneyCombWithERC20(bearId, 1); // minting 3 fails, need to mint exactly 1
        assertEq(honeycomb.balanceOf(clown), 1 + 2 + 1); // claimed 1, earlyMinted 2, mint 1 (reach cap)
        vm.stopPrank();

        /**
            Phase 5: End of Game
         */
        // Simulate VRF (RequestID = 1)
        vrfCoordinator.fulfillRandomWords(1, address(bearCave));
        (uint256 id, uint256 specialHoneycombId, , bool specialHoneycombFound, bool isAwake) = bearCave.bears(bearId);

        assertTrue(specialHoneycombFound);
        assertFalse(isAwake);
        console2.log("id: ", id);
        console2.log("specialHoneycombId: ", specialHoneycombId);
        /**
            Phase 6: Wake Bear
         */

        address winningAddress = honeycomb.ownerOf(specialHoneycombId);
        console2.log("winningAddress", winningAddress);
        vm.startPrank(winningAddress);
        assertEq(erc1155.balanceOf(winningAddress, bearId), 0);
        bearCave.wakeBear(bearId);
        assertEq(erc1155.balanceOf(winningAddress, bearId), 1);
        vm.stopPrank();

        console2.log("janiBal: ", paymentToken.balanceOf(jani));
        console2.log("beekeeper: ", paymentToken.balanceOf(beekeeper));
    }
}
