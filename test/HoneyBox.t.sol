// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "test/mocks/MockERC1155.sol";
import "test/mocks/MockERC20.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockVRFCoordinator.sol";
import "test/utils/UserFactory.sol";
import "test/utils/Random.sol";

import "src/HoneyBox.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/Constants.sol";

import {console2} from "forge-std/console2.sol";

contract HoneyBoxTest is Test, ERC1155TokenReceiver {
    using FixedPointMathLib for uint256;
    using Address for address;

    Merkle private merkleLib = new Merkle();

    uint256 private constant MINT_PRICE_ERC20 = 99 * 1e8;
    uint256 private constant MINT_PRICE_ETH = 99 * 1e6 * 1 gwei;

    // Scenario Setup
    uint32 private maxHoneyJar = 15;
    uint256 private honeyJarShare = 2233 * 1e14; // In WAD (.2233)
    uint32 private maxClaimableHoneyJar = 6;

    // Gatekeeper
    bytes32[] private gateData;
    bytes32 private gateRoot;

    // Dependencies
    uint256 private SFT_ID = 6969;
    uint256 private NFT_ID = 69696969;
    MockERC1155 private erc1155;
    MockERC721 private erc721;
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
    HoneyBox private honeyBox;
    HoneyBox.VRFConfig private vrfConfig;
    HoneyBox.MintConfig private mintConfig;
    HoneyJar private honeyJar;
    Gatekeeper private gatekeeper;

    // Game vars
    uint8 private bundleId;

    //Chainlink setup
    MockVRFCoordinator private vrfCoordinator;
    uint96 private constant FUND_AMOUNT = 1 * 10 ** 18;

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
        erc721 = new MockERC721("OOGA", "BOOGA");
        paymentToken = new MockERC20("OHM", "OHM", 9); // OHM is 9 decimals

        //Users
        beekeeper = payable(makeAddr("beekeeper"));
        jani = payable(makeAddr("definitelyNotJani"));
        gameAdmin = makeAddr("gameAdmin");
        alfaHunter = makeAddr("alfaHunter");
        bera = makeAddr("bera");
        clown = makeAddr("clown");

        // @solidity-ignore no-console
        console2.log("beekeeper: ", beekeeper);
        console2.log("jani: ", jani);
        console2.log("gameAdmin: ", gameAdmin);
        console2.log("alfaHunter: ", alfaHunter);
        console2.log("bera: ", bera);
        console2.log("clown: ", clown);
        console2.log("deployer: ", address(this));

        // Mint a bear to the gameAdmin
        erc1155.mint(gameAdmin, SFT_ID, 1, "");
        erc721.mint(gameAdmin, NFT_ID);

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

        honeyJar = new HoneyJar(address(gameRegistry), 69, 69);
        gatekeeper = new Gatekeeper(address(gameRegistry));

        honeyBox = new HoneyBox(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        mintConfig = HoneyBox.MintConfig({
            maxHoneyJar: maxHoneyJar,
            maxClaimableHoneyJar: maxClaimableHoneyJar,
            honeyJarPrice_ERC20: MINT_PRICE_ERC20, // 9.9 OHM
            honeyJarPrice_ETH: MINT_PRICE_ETH // 0.099 eth
        });

        // Set up on VRF site
        vrfCoordinator.addConsumer(subId, address(honeyBox));

        honeyBox.initialize(HoneyBox.VRFConfig("", subId, 3, 10000000), mintConfig);
        gameRegistry.registerGame(address(honeyBox));

        /**
         *   Generate roots
         */
        gateData = new bytes32[](3);
        gateData[0] = createNode(alfaHunter, 2);
        gateData[1] = createNode(bera, 3);
        gateData[2] = createNode(clown, 3);
        gateRoot = merkleLib.getRoot(gateData);
        gatekeeper.addGate(bundleId, gateRoot, maxClaimableHoneyJar + 1, 0);

        // Deployer doesn't have any perms after setup
        gameRegistry.renounceRole(Constants.GAME_ADMIN, address(this));

        // Game Admin Actions
        vm.startPrank(gameAdmin);
        gameRegistry.startGame(address(honeyBox));
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(erc721);
        tokenAddresses[1] = address(erc1155);
        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;
        bool[] memory isERC1155s = new bool[](2);
        isERC1155s[0] = false;
        isERC1155s[1] = true;

        bundleId = honeyBox.addBundle(tokenAddresses, tokenIDs, isERC1155s);
        erc721.approve(address(honeyBox), NFT_ID);
        erc1155.setApprovalForAll(address(honeyBox), true);
        honeyBox.puffPuffPassOut(bundleId);
        vm.stopPrank();
    }

    function testWorks() public {
        assertTrue(true);
    }

    function testFailAlreadyInitialized() public {
        honeyBox.initialize(HoneyBox.VRFConfig("", 0, 0, 0), mintConfig);
    }

    function testFailClaim_InvalidProof() public {
        vm.startPrank(alfaHunter);
        bytes32[] memory blankProof;
        honeyBox.claim(bundleId, 0, 2, blankProof);
    }

    function testFail_earlyMekETH() public {
        vm.startPrank(alfaHunter);
        bytes32[] memory blankProof;
        honeyBox.earlyMekHoneyJarWithEth(bundleId, 0, 2, blankProof, 2);
    }

    function testFail_earlyMekERC20() public {
        vm.startPrank(alfaHunter);

        bytes32[] memory blankProof;
        honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 2, blankProof, 2);
    }

    function testFullRun() public {
        // Get the first gate for validation

        (
            bool enabled,
            uint8 stageIndex,
            uint32 claimedCount,
            uint32 maxClaimable,
            bytes32 _gateRoot,
            uint256 activeAt
        ) = gatekeeper.tokenToGates(bundleId, 0);

        assertTrue(enabled);
        assertEq(stageIndex, 0);
        assertEq(claimedCount, 0);
        assertEq(maxClaimable, maxClaimableHoneyJar + 1);
        assertEq(_gateRoot, gateRoot);
        assertEq(activeAt, block.timestamp); // should be active now.

        /**
            Phase 1: claim available
         */

        assertEq(gatekeeper.claim(bundleId, 0, alfaHunter, 2, getProof(0)), 2);
        vm.startPrank(alfaHunter);
        honeyBox.claim(bundleId, 0, 2, getProof(0));
        assertEq(honeyJar.balanceOf(alfaHunter), 2);
        vm.stopPrank();

        vm.startPrank(bera);
        honeyBox.claim(bundleId, 0, 3, getProof(1));
        assertEq(honeyJar.balanceOf(bera), 3);
        vm.stopPrank();

        vm.startPrank(clown);
        honeyBox.claim(bundleId, 0, 3, getProof(2));
        assertEq(honeyJar.balanceOf(clown), 1);
        vm.stopPrank();

        // Gate claimable is > game claimable.
        // Game claimable clamps number of allowed mints.
        assertEq(honeyBox.claimed(bundleId), 6);
        (, , claimedCount, maxClaimable, , ) = gatekeeper.tokenToGates(bundleId, 0);
        assertEq(claimedCount, 6);
        assertEq(maxClaimable, 7);

        /**
            Phase 2: do it again:
            Do it again, and validate nothing changes.
         */

        vm.startPrank(alfaHunter);
        honeyBox.claim(bundleId, 0, 2, getProof(0));
        assertEq(honeyJar.balanceOf(alfaHunter), 2);
        vm.stopPrank();

        vm.startPrank(bera);
        honeyBox.claim(bundleId, 0, 3, getProof(1));
        assertEq(honeyJar.balanceOf(bera), 3);
        vm.stopPrank();

        vm.startPrank(clown);
        honeyBox.claim(bundleId, 0, 3, getProof(2));
        assertEq(honeyJar.balanceOf(clown), 1);
        vm.stopPrank();
        /**
            Phase 3: early mint 
         */

        // Can also validate jani/beekeeper balances

        vm.startPrank(alfaHunter);
        paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
        honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 2, getProof(0), 1);
        assertEq(honeyJar.balanceOf(alfaHunter), 3);
        vm.stopPrank();

        vm.startPrank(bera);
        paymentToken.approve(address(honeyBox), 3 * MINT_PRICE_ERC20);
        honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 3, getProof(1), 2);
        assertEq(honeyJar.balanceOf(bera), 5); //claimed 3, early minted 2
        vm.stopPrank();

        vm.deal(clown, MINT_PRICE_ETH);
        vm.startPrank(clown);
        paymentToken.approve(address(honeyBox), 3 * MINT_PRICE_ERC20);
        honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 3, getProof(2), 1);
        honeyBox.earlyMekHoneyJarWithEth{value: MINT_PRICE_ETH}(bundleId, 0, 3, getProof(2), 1);

        assertEq(honeyJar.balanceOf(clown), 3); // claimed 1, earlyMinted 2
        vm.stopPrank();

        /**
            Phase 4: general Mint
         */
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(bera);
        paymentToken.approve(address(honeyBox), 3 * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 3);
        assertEq(honeyJar.balanceOf(bera), 3 + 2 + 3); //claimed 3, early minted 2, mint 3
        vm.stopPrank();

        vm.startPrank(clown);
        paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 1); // minting 3 fails, need to mint exactly 1
        assertEq(honeyJar.balanceOf(clown), 1 + 2 + 1); // claimed 1, earlyMinted 2, mint 1 (reach cap)
        vm.stopPrank();

        /**
            Phase 5: End of Game
         */
        // Simulate VRF (RequestID = 1)
        vrfCoordinator.fulfillRandomWords(1, address(honeyBox));
        (uint256 id, uint256 specialhoneyJarId, , bool specialhoneyJarFound, bool isAwake) = honeyBox.slumberParties(
            bundleId
        );

        assertTrue(specialhoneyJarFound);
        assertFalse(isAwake);
        console2.log("id: ", id);
        console2.log("specialhoneyJarId: ", specialhoneyJarId);
        /**
            Phase 6: Wake Bear
         */

        address winningAddress = honeyJar.ownerOf(specialhoneyJarId);
        console2.log("winningAddress", winningAddress);
        vm.startPrank(winningAddress);
        assertEq(erc1155.balanceOf(winningAddress, SFT_ID), 0);
        assertEq(erc721.balanceOf(winningAddress), 0);

        honeyBox.openHotBox(bundleId);
        assertEq(erc1155.balanceOf(winningAddress, SFT_ID), 1);
        assertEq(erc721.balanceOf(winningAddress), 1);
        vm.stopPrank();

        console2.log("janiBal: ", paymentToken.balanceOf(jani));
        console2.log("beekeeper: ", paymentToken.balanceOf(beekeeper));
    }
}
