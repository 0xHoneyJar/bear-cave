// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {LayerZeroHelper} from "pigeon/layerzero/LayerZeroHelper.sol";

import {MockERC1155, ERC1155TokenReceiver} from "test/mocks/MockERC1155.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC721, ERC721TokenReceiver} from "test/mocks/MockERC721.sol";
import {MockVRFCoordinator} from "test/mocks/MockVRFCoordinator.sol";

import {HibernationDen} from "src/HibernationDen.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/Constants.sol";
import {CrossChainTHJ} from "src/CrossChainTHJ.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";

contract XChainHibernationDenTest is Test, ERC721TokenReceiver, ERC1155TokenReceiver {
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using Address for address;

    Merkle private merkleLib;

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
    MockERC1155 private erc1155L2;
    MockERC721 private erc721L2;
    MockERC20 private paymentTokenL2;

    // Users
    address payable private beekeeper;
    address payable private jani;
    address private gameAdmin;
    address private alfaHunter; //0
    address private bera; // 1
    address private clown; // 2

    // Deployables
    GameRegistry private gameRegistry;
    HibernationDen private honeyBox;
    HibernationDen.VRFConfig private vrfConfig;
    HibernationDen.MintConfig private mintConfig;
    HoneyJar private honeyJar;
    Gatekeeper private gatekeeper;
    HoneyJarPortal private portal;

    // Deployables
    GameRegistry private gameRegistryL2;
    HibernationDen private honeyBoxL2;
    HibernationDen.VRFConfig private vrfConfigL2;
    HibernationDen.MintConfig private mintConfigL2;
    HoneyJar private honeyJarL2;
    Gatekeeper private gatekeeperL2;
    HoneyJarPortal private portalL2;

    // Game vars
    uint8 private bundleId;
    uint256[] private checkpoints;

    //Chainlink setup
    MockVRFCoordinator private vrfCoordinator;
    MockVRFCoordinator private vrfCoordinatorL2;
    uint64 private subId;
    uint64 private subIdL2;
    uint96 private constant FUND_AMOUNT = 1 * 10 ** 18;

    //Helpers
    LayerZeroHelper lzHelper;

    string RPC_GOERLI = vm.envString("GOERLI_URL");
    string RPC_ARB_GOERLI = vm.envString("ARB_GOERLI_URL");

    uint256 L1_FORK_ID;
    uint256 L2_FORK_ID;

    uint256 L1_CHAIN_ID = 5;
    uint256 L2_CHAIN_ID = 421613;

    address L1_LZ_ENDPOINT = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    address L2_LZ_ENDPOINT = 0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab;

    function createNode(address player, uint32 amount) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(player, amount));
    }

    function getProof(uint256 idx) private view returns (bytes32[] memory) {
        return merkleLib.getProof(gateData, idx);
    }

    // Initialize the test suite
    function setUp() public {
        L1_FORK_ID = vm.createFork(RPC_GOERLI);
        L2_FORK_ID = vm.createFork(RPC_ARB_GOERLI);

        merkleLib = new Merkle();
        lzHelper = new LayerZeroHelper();

        vm.makePersistent(address(merkleLib));
        vm.makePersistent(address(lzHelper));

        beekeeper = payable(makeAddr("beekeeper"));
        jani = payable(makeAddr("definitelyNotJani"));
        gameAdmin = makeAddr("gameAdmin");
        alfaHunter = makeAddr("alfaHunter");
        bera = makeAddr("bera");
        clown = makeAddr("clown");

        vm.selectFork(L1_FORK_ID);

        vm.deal(gameAdmin, 100 ether);
        vm.deal(alfaHunter, 100 ether);
        vm.deal(bera, 100 ether);
        vm.deal(clown, 100 ether);

        erc1155 = new MockERC1155();
        erc721 = new MockERC721("OOGA", "BOOGA");
        paymentToken = new MockERC20("OHM", "OHM", 9); // OHM is 9 decimals

        // Mint winning NFTs to the gameAdmin (L1)
        erc1155.mint(gameAdmin, SFT_ID, 1, "");
        erc721.mint(gameAdmin, NFT_ID);
        erc721.mint(gameAdmin, NFT_ID + 1);
        erc721.mint(gameAdmin, NFT_ID + 2);
        erc721.mint(gameAdmin, NFT_ID + 3);
        erc721.mint(gameAdmin, NFT_ID + 4);

        // Chainlink setup (L1)
        vrfCoordinator = new MockVRFCoordinator();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        // Deploy contracts (L1)
        gameRegistry = new GameRegistry();
        // Transfer gameAdmin to real Admin
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        honeyJar = new HoneyJar(address(this), address(gameRegistry), START_TOKEN_ID, 69);
        gatekeeper = new Gatekeeper(address(gameRegistry));

        honeyBox = new HibernationDen(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        portal = new HoneyJarPortal(100000, L1_LZ_ENDPOINT, address(honeyJar),address(honeyBox), address(gameRegistry));

        mintConfig = HibernationDen.MintConfig({
            maxClaimableHoneyJar: maxClaimableHoneyJar,
            honeyJarPrice_ERC20: MINT_PRICE_ERC20, // 9.9 OHM
            honeyJarPrice_ETH: MINT_PRICE_ETH // 0.099 eth
        });

        // Set up on VRF site
        vrfCoordinator.addConsumer(subId, address(honeyBox));

        honeyBox.initialize(HibernationDen.VRFConfig("", subId, 3, 10000000), mintConfig);
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
        (address[] memory tokenAddresses, uint256[] memory tokenIDs, bool[] memory isERC1155s) = _getBundleInput();

        checkpoints = new uint256[](4);
        checkpoints[0] = 3;
        checkpoints[1] = 6;
        checkpoints[2] = 12;
        checkpoints[3] = maxHoneyJar;

        bundleId = honeyBox.addBundle(421613, checkpoints, tokenAddresses, tokenIDs, isERC1155s);

        erc721.approve(address(honeyBox), NFT_ID);
        erc721.approve(address(honeyBox), NFT_ID + 1);
        erc721.approve(address(honeyBox), NFT_ID + 2);
        erc721.approve(address(honeyBox), NFT_ID + 3);
        erc721.approve(address(honeyBox), NFT_ID + 4);

        erc1155.setApprovalForAll(address(honeyBox), true);

        gameRegistry.startGame(address(honeyBox));
        honeyBox.setPortal(address(portal));
        vm.stopPrank();

        // Deployments (L2)
        vm.selectFork(L2_FORK_ID);

        vm.deal(gameAdmin, 100 ether);
        vm.deal(alfaHunter, 100 ether);
        vm.deal(bera, 100 ether);
        vm.deal(clown, 100 ether);

        erc1155L2 = new MockERC1155();
        erc721L2 = new MockERC721("OOGA", "BOOGA");
        paymentTokenL2 = new MockERC20("OHM", "OHM", 9); // OHM is 9 decimals

        paymentTokenL2.mint(alfaHunter, MINT_PRICE_ERC20 * 100);
        paymentTokenL2.mint(bera, MINT_PRICE_ERC20 * 100);
        paymentTokenL2.mint(clown, MINT_PRICE_ERC20 * 100);
        paymentTokenL2.mint(address(this), MINT_PRICE_ERC20 * 5);

        // Chainlink setup (L2)
        vrfCoordinatorL2 = new MockVRFCoordinator();
        subIdL2 = vrfCoordinatorL2.createSubscription();
        vrfCoordinatorL2.fundSubscription(subIdL2, FUND_AMOUNT);

        // Deploy contracts (L2)
        gameRegistryL2 = new GameRegistry();
        // Transfer gameAdmin to real Admin
        gameRegistryL2.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistryL2.setJani(jani);
        gameRegistryL2.setBeekeeper(beekeeper);

        honeyJarL2 = new HoneyJar(address(this), address(gameRegistryL2), START_TOKEN_ID, 69);
        gatekeeperL2 = new Gatekeeper(address(gameRegistryL2));

        honeyBoxL2 = new HibernationDen(
            address(vrfCoordinatorL2),
            address(gameRegistryL2),
            address(honeyJarL2),
            address(paymentTokenL2),
            address(gatekeeperL2),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        portalL2 =
            new HoneyJarPortal(100000, L2_LZ_ENDPOINT, address(honeyJarL2),address(honeyBoxL2), address(gameRegistryL2));
        honeyBoxL2.setPortal(address(portalL2));

        // Set trusted remotes
        vm.selectFork(L1_FORK_ID);
        portal.setTrustedRemote(portal.lzChainId(L2_CHAIN_ID), abi.encodePacked(address(portalL2), address(portal)));

        vm.selectFork(L2_FORK_ID);
        portalL2.setTrustedRemote(portalL2.lzChainId(L1_CHAIN_ID), abi.encodePacked(address(portal), address(portalL2)));

        // Initiate xChain game start from L1
        vm.selectFork(L1_FORK_ID);
        vm.recordLogs();
        vm.prank(gameAdmin);
        honeyBox.puffPuffPassOut{value: 1 ether}(bundleId);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        lzHelper.help(L2_LZ_ENDPOINT, 100000, L2_FORK_ID, logs);
    }

    function testCrossChain() public {
        // For simplicity's sake, reuse most dependencies.
        vm.selectFork(L1_FORK_ID);

        // Set up portal address (contract or user)
        address portal = makeAddr("portal");
        vm.deal(portal, 100 ether);
        gameRegistry.grantRole(Constants.PORTAL, portal);

        HibernationDen l1HibernationDen = honeyBox;

        // Deploy l2 on a new chain
        vm.selectFork(L2_FORK_ID);

        HibernationDen l2HibernationDen = new HibernationDen(
            address(vrfCoordinatorL2),
            address(gameRegistryL2),
            address(honeyJarL2),
            address(paymentTokenL2),
            address(gatekeeperL2),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        vrfCoordinatorL2.addConsumer(subId, address(l2HibernationDen));

        // Do the rest on main chain
        vm.selectFork(L1_FORK_ID);

        (address[] memory tokenAddresses, uint256[] memory tokenIDs, bool[] memory isERC1155s) = _getBundleInput();

        // Only game Admin actions
        vm.startPrank(gameAdmin);
        l2HibernationDen.initialize(HibernationDen.VRFConfig("", subId, 3, 10000000), mintConfig);
        gameRegistry.registerGame(address(l2HibernationDen));
        gameRegistry.startGame(address(l2HibernationDen));

        uint8 newBundleId = l1HibernationDen.addBundle(L2_CHAIN_ID, checkpoints, tokenAddresses, tokenIDs, isERC1155s);
        gatekeeper.addGate(newBundleId, gateRoot, maxClaimableHoneyJar + 1, 0);
        vm.stopPrank();

        uint256[] memory newCheckpoints = new uint256[](1);
        newCheckpoints[0] = maxHoneyJar;

        vm.startPrank(portal);
        l2HibernationDen.startGame(L1_CHAIN_ID, newBundleId, tokenAddresses.length, newCheckpoints);
        vm.stopPrank();

        // Assuming the claiming flow works the same from below. Go to GeneralMint
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(alfaHunter);
        // l1HibernationDen.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5); Fails as expected
        l2HibernationDen.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        vm.startPrank(bera);
        l2HibernationDen.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        vm.startPrank(clown);
        l2HibernationDen.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(newBundleId, 5);
        vm.stopPrank();

        // Get winnors
        vrfCoordinator.fulfillRandomWords(1, address(l2HibernationDen));
        HibernationDen.SlumberParty memory party = l2HibernationDen.getSlumberParty(newBundleId);
        assertEq(party.fermentedJarsFound, true, "fermentedJarsFound should be true");
        assertEq(party.assetChainId, L1_CHAIN_ID, "assetChainId is incorrect");
        assertEq(party.mintChainId, L2_CHAIN_ID, "mintChainId is incorrect");
        assertEq(party.fermentedJars.length, tokenAddresses.length, "fermented jars != num sleepers");

        // Communicate Via portal
        vm.startPrank(portal);
        uint256[] memory fermentedJarIds = new uint256[](party.fermentedJars.length);
        for (uint256 i = 0; i < party.fermentedJars.length; i++) {
            fermentedJarIds[i] = party.fermentedJars[i].id;
        }
        vm.recordLogs();
        l1HibernationDen.setCrossChainFermentedJars(newBundleId, fermentedJarIds);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        lzHelper.help(0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab, 100000, 421613, logs);
        vm.stopPrank();

        // Players **MUST** bridge their winning NFT to the assetChainId in order to wake sleeper.

        // Test out a particular winner
        uint256 fermentedJarId = party.fermentedJars[0].id;
        address winner = honeyJar.ownerOf(fermentedJarId);

        vm.startPrank(winner);
        // l2HibernationDen.wakeSleeper(newBundleId, fermentedJarId);  This fails like it should
        l1HibernationDen.wakeSleeper(newBundleId, fermentedJarId);
    }

    // function testFullRun() public {
    //     // Get the first gate for validation
    //     (bool enabled, uint8 stageIndex, uint32 claimedCount, uint32 maxClaimable, bytes32 _gateRoot, uint256 activeAt)
    //     = gatekeeper.tokenToGates(bundleId, 0);

    //     assertTrue(enabled);
    //     assertEq(stageIndex, 0);
    //     assertEq(claimedCount, 0);
    //     assertEq(maxClaimable, maxClaimableHoneyJar + 1);
    //     assertEq(_gateRoot, gateRoot);
    //     assertEq(activeAt, block.timestamp); // should be active now.

    //     /**
    //      * Phase 1: claim available
    //      */

    //     assertEq(gatekeeper.calculateClaimable(bundleId, 0, alfaHunter, 2, getProof(0)), 2);
    //     vm.startPrank(alfaHunter);
    //     honeyBox.claim(bundleId, 0, 2, getProof(0));
    //     assertEq(honeyJar.balanceOf(alfaHunter), 2);
    //     vm.stopPrank();

    //     vm.startPrank(bera);
    //     honeyBox.claim(bundleId, 0, 3, getProof(1));
    //     assertEq(honeyJar.balanceOf(bera), 3);
    //     vm.stopPrank();

    //     // Checkpoint 1 = 3
    //     vrfCoordinator.fulfillRandomWords(1, address(honeyBox));
    //     _validateWinners();

    //     vm.startPrank(clown);
    //     honeyBox.claim(bundleId, 0, 3, getProof(2));
    //     assertEq(honeyJar.balanceOf(clown), 1);
    //     vm.stopPrank();

    //     // Checkpoint 2 = 6
    //     vrfCoordinator.fulfillRandomWords(2, address(honeyBox));
    //     _validateWinners();

    //     // Gate claimable is > game claimable.
    //     // Game claimable clamps number of allowed mints.
    //     assertEq(honeyBox.claimed(bundleId), 6);
    //     (,, claimedCount, maxClaimable,,) = gatekeeper.tokenToGates(bundleId, 0);
    //     assertEq(claimedCount, 6);
    //     assertEq(maxClaimable, 7);

    //     /**
    //      * Phase 2: do it again:
    //      *         Do it again, and validate nothing changes.
    //      */

    //     vm.startPrank(alfaHunter);
    //     honeyBox.claim(bundleId, 0, 2, getProof(0));
    //     assertEq(honeyJar.balanceOf(alfaHunter), 2);
    //     vm.stopPrank();

    //     vm.startPrank(bera);
    //     honeyBox.claim(bundleId, 0, 3, getProof(1));
    //     assertEq(honeyJar.balanceOf(bera), 3);
    //     vm.stopPrank();

    //     vm.startPrank(clown);
    //     honeyBox.claim(bundleId, 0, 3, getProof(2));
    //     assertEq(honeyJar.balanceOf(clown), 1);
    //     vm.stopPrank();

    //     /**
    //      * Phase 3: early mint
    //      */

    //     // Can also validate jani/beekeeper balances

    //     vm.startPrank(alfaHunter);
    //     paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
    //     honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 2, getProof(0), 1);
    //     assertEq(honeyJar.balanceOf(alfaHunter), 3);
    //     vm.stopPrank();

    //     vm.startPrank(bera);
    //     paymentToken.approve(address(honeyBox), 3 * MINT_PRICE_ERC20);
    //     honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 3, getProof(1), 2);
    //     assertEq(honeyJar.balanceOf(bera), 5); //claimed 3, early minted 2
    //     vm.stopPrank();

    //     vm.deal(clown, MINT_PRICE_ETH);
    //     vm.startPrank(clown);
    //     paymentToken.approve(address(honeyBox), 3 * MINT_PRICE_ERC20);
    //     honeyBox.earlyMekHoneyJarWithERC20(bundleId, 0, 3, getProof(2), 1);
    //     honeyBox.earlyMekHoneyJarWithEth{value: MINT_PRICE_ETH}(bundleId, 0, 3, getProof(2), 1);

    //     assertEq(honeyJar.balanceOf(clown), 3); // claimed 1, earlyMinted 2
    //     vm.stopPrank();

    //     /**
    //      * Phase 4: general Mint
    //      */
    //     vm.warp(block.timestamp + 72 hours);

    //     vm.deal(bera, MINT_PRICE_ETH);
    //     vm.startPrank(bera);
    //     paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
    //     honeyBox.mekHoneyJarWithERC20(bundleId, 2);
    //     honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH}(bundleId, 1);
    //     assertEq(honeyJar.balanceOf(bera), 3 + 2 + 3); //claimed 3, early minted 2, mint 3
    //     vm.stopPrank();

    //     // Checkpoint 3 = 12
    //     vrfCoordinator.fulfillRandomWords(3, address(honeyBox));
    //     _validateWinners();

    //     vm.startPrank(clown);
    //     paymentToken.approve(address(honeyBox), 2 * MINT_PRICE_ERC20);
    //     honeyBox.mekHoneyJarWithERC20(bundleId, 1); // minting 3 fails, need to mint exactly 1
    //     assertEq(honeyJar.balanceOf(clown), 1 + 2 + 1); // claimed 1, earlyMinted 2, mint 1 (reach cap)
    //     vm.stopPrank();

    //     /**
    //      * Phase 5: End of Game
    //      */

    //     vrfCoordinator.fulfillRandomWords(4, address(honeyBox)); // Final winner
    //     HibernationDen.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);

    //     assertEq(party.bundleId, bundleId);
    //     assertTrue(party.fermentedJarsFound);
    //     assertEq(party.fermentedJars.length, party.sleepoors.length, "fermented jars != sleepers");
    //     console.log("id: ", party.bundleId);

    //     /**
    //      * Phase 6: Wake NFTs
    //      */

    //     // for (uint256 i = 0; i < party.fermentedJars.length; i++) {
    //     //     _checkWinner(party.fermentedJars[i].id, party.sleepoors[i]);
    //     // }

    //     console.log("janiBal: ", paymentToken.balanceOf(jani));
    //     console.log("beekeeper: ", paymentToken.balanceOf(beekeeper));
    // }

    /////

    function _getBundleInput()
        internal
        returns (address[] memory tokenAddresses, uint256[] memory tokenIDs, bool[] memory isERC1155s)
    {
        tokenAddresses = new address[](6);
        tokenAddresses[0] = address(erc721);
        tokenAddresses[1] = address(erc1155);
        tokenAddresses[2] = address(erc721);
        tokenAddresses[3] = address(erc721);
        tokenAddresses[4] = address(erc721);
        tokenAddresses[5] = address(erc721);

        tokenIDs = new uint256[](6);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;
        tokenIDs[2] = NFT_ID + 1;
        tokenIDs[3] = NFT_ID + 2;
        tokenIDs[4] = NFT_ID + 3;
        tokenIDs[5] = NFT_ID + 4;

        isERC1155s = new bool[](6);
        isERC1155s[0] = false;
        isERC1155s[1] = true;
        isERC1155s[2] = false;
        isERC1155s[3] = false;
        isERC1155s[4] = false;
        isERC1155s[5] = false;
    }

    function _checkWinner(uint256 winningID, HibernationDen.SleepingNFT memory sleeper) internal {
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

    function _validateWinners() internal {
        HibernationDen.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        assertTrue(party.fermentedJarsFound);

        address winner;
        uint256 alreadyWon;
        HibernationDen.FermentedJar memory fermentedJar;
        for (uint256 i = 0; i < party.fermentedJars.length; ++i) {
            fermentedJar = party.fermentedJars[i];
            if (fermentedJar.isUsed) {
                // Skip if the jar is used.
                continue;
            }
            // Jar isn't used, so wake it up
            winner = honeyJar.ownerOf(fermentedJar.id);
            alreadyWon = erc721.balanceOf(winner) + erc1155.balanceOf(winner, SFT_ID);
            vm.startPrank(winner);
            honeyBox.wakeSleeper(bundleId, fermentedJar.id); // Validate an NFT transfer occured.
            vm.stopPrank();
            assertEq(erc721.balanceOf(winner) + erc1155.balanceOf(winner, SFT_ID), alreadyWon + 1);
        }
    }

    receive() external payable {
        
    }
}
