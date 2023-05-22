// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {MockERC1155, ERC1155TokenReceiver} from "test/mocks/MockERC1155.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC721, ERC721TokenReceiver} from "test/mocks/MockERC721.sol";
import {MockVRFCoordinator} from "test/mocks/MockVRFCoordinator.sol";

import {HoneyBox} from "src/HoneyBox.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/Constants.sol";
import {CrossChainTHJ} from "src/CrossChainTHJ.sol";

contract HoneyBoxTest is Test, ERC721TokenReceiver, ERC1155TokenReceiver {
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using Address for address;

    Merkle private merkleLib = new Merkle();

    uint256 private constant MINT_PRICE_ERC20 = 99 * 1e8;
    uint256 private constant MINT_PRICE_ETH = 99 * 1e6 * 1 gwei;
    uint256 private constant START_TOKEN_ID = 69;

    // Scenario Setup
    uint32 private maxHoneyJar = 15;
    uint256 private honeyJarShare = 2233 * 1e14; // In WD (.2233)
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
    uint64 private subId;
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
        vm.deal(gameAdmin, 100 ether);
        alfaHunter = makeAddr("alfaHunter");
        vm.deal(alfaHunter, 100 ether);
        bera = makeAddr("bera");
        vm.deal(bera, 100 ether);
        clown = makeAddr("clown");
        vm.deal(clown, 100 ether);

        // @solidity-ignore no-console
        console.log("beekeeper: ", beekeeper);
        console.log("jani: ", jani);
        console.log("gameAdmin: ", gameAdmin);
        console.log("alfaHunter: ", alfaHunter);
        console.log("bera: ", bera);
        console.log("clown: ", clown);
        console.log("deployer: ", address(this));

        // Mint a bear to the gameAdmin
        erc1155.mint(gameAdmin, SFT_ID, 1, "");
        erc721.mint(gameAdmin, NFT_ID);

        paymentToken.mint(alfaHunter, MINT_PRICE_ERC20 * 100);
        paymentToken.mint(bera, MINT_PRICE_ERC20 * 100);
        paymentToken.mint(clown, MINT_PRICE_ERC20 * 100);
        paymentToken.mint(address(this), MINT_PRICE_ERC20 * 5);

        // Chainlink setup
        vrfCoordinator = new MockVRFCoordinator();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        /**
         * Deploy contracts
         */
        gameRegistry = new GameRegistry();
        // Transfer gameAdmin to real Admin
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        honeyJar = new HoneyJar(address(this), address(gameRegistry), START_TOKEN_ID, 69);
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
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(erc721);
        tokenAddresses[1] = address(erc1155);
        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;
        bool[] memory isERC1155s = new bool[](2);
        isERC1155s[0] = false;
        isERC1155s[1] = true;

        bundleId = honeyBox.addBundle(block.chainid, tokenAddresses, tokenIDs, isERC1155s);

        uint256[] memory checkpoints = new uint256[](3);
        checkpoints[0] = 3;
        checkpoints[1] = 6;
        checkpoints[2] = 12;
        honeyBox.setCheckpoints(bundleId, checkpoints);
        erc721.approve(address(honeyBox), NFT_ID);
        erc1155.setApprovalForAll(address(honeyBox), true);

        gameRegistry.startGame(address(honeyBox));
        honeyBox.puffPuffPassOut(bundleId);
        vm.stopPrank();
    }

    function testWorks() public {
        assertTrue(true);
    }

    function testFailAlreadyInitialized() public {
        vm.prank(address(gameAdmin));
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

    function testFailMekHoney_InvalidBundle() public {
        honeyBox.mekHoneyJarWithERC20(69, 1);
    }

    function testFail_mekHJNotGenMint_ERC20() public {
        honeyBox.mekHoneyJarWithERC20(bundleId, 1);
    }

    function testFail_mekHJNotGenMint_ETH() public {
        honeyBox.mekHoneyJarWithETH(bundleId, 1);
    }

    function testFail_mekWrongETHValue() public {
        vm.warp(block.timestamp + 72 hours);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH - 1}(bundleId, 1);
    }

    function test_mekWithETH() public {
        vm.warp(block.timestamp + 72 hours);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH}(bundleId, 1);
    }

    function test_mekWithERC20() public {
        vm.warp(block.timestamp + 72 hours);

        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20 * 3);
        honeyBox.mekHoneyJarWithERC20(bundleId, 3);
    }

    function testFailEarlyWakeAttempt() public {
        vm.warp(block.timestamp + 72 hours);

        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20 * 3);
        honeyBox.mekHoneyJarWithERC20(bundleId, 3);

        honeyBox.wakeSleeper(bundleId, START_TOKEN_ID);
    }

    function testMultipleWinners() public {
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(alfaHunter);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        vm.startPrank(bera);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        vm.startPrank(clown);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        vrfCoordinator.fulfillRandomWords(1, address(honeyBox));

        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);

        assertEq(party.bundleId, bundleId);
        assertEq(party.fermentedJars.length, 2, "wrong # of fermented jars");
        assertEq(party.sleepoors.length, 2, "wrong # of sleepers");
    }

    function testCrossChain() public {
        // For simplicity's sake, reuse most dependencies.
        uint256 l1ChainId = block.chainid;
        uint256 l2ChainId = l1ChainId + 10000;

        // Set up portal address (contract or user)
        address portal = makeAddr("portal");
        vm.deal(portal, 100 ether);
        gameRegistry.grantRole(Constants.PORTAL, portal);

        HoneyBox l1HoneyBox = honeyBox;

        // Deploy l2 on a new chain
        vm.chainId(l2ChainId);
        HoneyBox l2HoneyBox = new HoneyBox(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        vrfCoordinator.addConsumer(subId, address(l2HoneyBox));

        // Do the rest on main chain
        vm.chainId(l1ChainId);

        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(erc721);
        tokenAddresses[1] = address(erc1155);
        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;
        bool[] memory isERC1155s = new bool[](2);
        isERC1155s[0] = false;
        isERC1155s[1] = true;

        // Only game Admin actions
        vm.startPrank(gameAdmin);
        l2HoneyBox.initialize(HoneyBox.VRFConfig("", subId, 3, 10000000), mintConfig);
        gameRegistry.registerGame(address(l2HoneyBox));
        gameRegistry.startGame(address(l2HoneyBox));

        uint8 newBundleId = l1HoneyBox.addBundle(l2ChainId.safeCastTo16(), tokenAddresses, tokenIDs, isERC1155s);
        gatekeeper.addGate(newBundleId, gateRoot, maxClaimableHoneyJar + 1, 0);
        vm.stopPrank();

        // wtf idk why vm.changePrank doesn't work

        vm.startPrank(portal);
        l2HoneyBox.startGame(l1ChainId, newBundleId, tokenAddresses.length);
        vm.stopPrank();

        // Assuming the claiming flow works the same from below. Go to GeneralMint
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(alfaHunter);
        // l1HoneyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5); Fails as expected
        l2HoneyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        vm.startPrank(bera);
        l2HoneyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        vm.startPrank(clown);
        l2HoneyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        // Get winnors
        vrfCoordinator.fulfillRandomWords(1, address(l2HoneyBox));
        HoneyBox.SlumberParty memory party = l2HoneyBox.getSlumberParty(newBundleId);
        assertEq(party.fermentedJarsFound, true, "fermentedJarsFound should be true");
        assertEq(party.assetChainId, l1ChainId, "assetChainId is incorrect");
        assertEq(party.mintChainId, l2ChainId, "mintChainId is incorrect");
        assertEq(party.fermentedJars.length, tokenAddresses.length);

        // Communicate Via portal
        vm.startPrank(portal);
        uint256[] memory fermentedJarIds = new uint256[](party.fermentedJars.length);
        for (uint256 i = 0; i < party.fermentedJars.length; i++) {
            fermentedJarIds[i] = party.fermentedJars[i].id;
        }
        l1HoneyBox.setCrossChainFermentedJars(newBundleId, fermentedJarIds);
        vm.stopPrank();

        // Players **MUST** bridge their winning NFT to the assetChainId in order to wake sleeper.

        // Test out a particular winner
        uint256 fermentedJarId = party.fermentedJars[0].id;
        address winner = honeyJar.ownerOf(fermentedJarId);

        vm.startPrank(winner);
        // l2HoneyBox.wakeSleeper(newBundleId, fermentedJarId);  This fails like it should
        l1HoneyBox.wakeSleeper(newBundleId, fermentedJarId);
    }

    function testFullRun() public {
        // Get the first gate for validation

        (bool enabled, uint8 stageIndex, uint32 claimedCount, uint32 maxClaimable, bytes32 _gateRoot, uint256 activeAt)
        = gatekeeper.tokenToGates(bundleId, 0);

        assertTrue(enabled);
        assertEq(stageIndex, 0);
        assertEq(claimedCount, 0);
        assertEq(maxClaimable, maxClaimableHoneyJar + 1);
        assertEq(_gateRoot, gateRoot);
        assertEq(activeAt, block.timestamp); // should be active now.

        /**
         * Phase 1: claim available
         */

        assertEq(gatekeeper.calculateClaimable(bundleId, 0, alfaHunter, 2, getProof(0)), 2);
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
        (,, claimedCount, maxClaimable,,) = gatekeeper.tokenToGates(bundleId, 0);
        assertEq(claimedCount, 6);
        assertEq(maxClaimable, 7);

        /**
         * Phase 2: do it again:
         *         Do it again, and validate nothing changes.
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
         * Phase 3: early mint
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
         * Phase 4: general Mint
         */
        vm.warp(block.timestamp + 72 hours);

        vm.deal(bera, MINT_PRICE_ETH);
        vm.startPrank(bera);
        paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 2);
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH}(bundleId, 1);
        assertEq(honeyJar.balanceOf(bera), 3 + 2 + 3); //claimed 3, early minted 2, mint 3
        vm.stopPrank();

        vm.startPrank(clown);
        paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 1); // minting 3 fails, need to mint exactly 1
        assertEq(honeyJar.balanceOf(clown), 1 + 2 + 1); // claimed 1, earlyMinted 2, mint 1 (reach cap)
        vm.stopPrank();

        /**
         * Phase 5: End of Game
         */
        // Simulate VRF (RequestID = 1)

        vrfCoordinator.fulfillRandomWords(1, address(honeyBox));
        vrfCoordinator.fulfillRandomWords(2, address(honeyBox));
        vrfCoordinator.fulfillRandomWords(3, address(honeyBox));

        honeyBox.slumberParties(bundleId);
        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);

        assertEq(party.bundleId, bundleId);
        assertTrue(party.fermentedJarsFound);
        assertEq(party.fermentedJars.length, party.sleepoors.length);
        console.log("id: ", party.bundleId);
        /**
         * Phase 6: Wake NFTs
         */

        for (uint256 i = 0; i < party.fermentedJars.length; i++) {
            _checkWinner(party.fermentedJars[i].id, party.sleepoors[i]);
        }

        console.log("janiBal: ", paymentToken.balanceOf(jani));
        console.log("beekeeper: ", paymentToken.balanceOf(beekeeper));
    }

    function _checkWinner(uint256 winningID, HoneyBox.SleepingNFT memory sleeper) internal {
        address winner = honeyJar.ownerOf(winningID);
        if (sleeper.isERC1155) {
            assertEq(erc1155.balanceOf(winner, SFT_ID), 0);
        } else {
            assertEq(erc721.balanceOf(winner), 0);
        }

        vm.startPrank(winner);
        honeyBox.wakeSleeper(bundleId, winningID);
        if (sleeper.isERC1155) {
            assertEq(erc1155.balanceOf(winner, SFT_ID), 1);
        } else {
            assertEq(erc721.balanceOf(winner), 1);
        }
        vm.stopPrank();
    }
}
