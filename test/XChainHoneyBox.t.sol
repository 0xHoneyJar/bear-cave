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

    // L1 Deployables
    GameRegistry private gameRegistry;
    HibernationDen private hibernationDenL1;
    HibernationDen.VRFConfig private vrfConfig;
    HibernationDen.MintConfig private mintConfig;
    HoneyJar private honeyJar;
    Gatekeeper private gatekeeper;
    HoneyJarPortal private portalL1;

    // L2 Deployables
    GameRegistry private gameRegistryL2;
    HibernationDen private hibernationDenL2;
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
    LayerZeroHelper private lzHelper;

    string private RPC_GOERLI = vm.envString("GOERLI_URL");
    string private RPC_ARB_GOERLI = vm.envString("ARB_GOERLI_URL");

    uint256 private L1_FORK_ID;
    uint256 private L2_FORK_ID;

    uint256 private L1_CHAIN_ID = 5;
    uint256 private L2_CHAIN_ID = 421613;

    address private L1_LZ_ENDPOINT = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    address private L2_LZ_ENDPOINT = 0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab;

    address private L1_DEFAULT_LIBRARY = 0x6f3a314C1279148E53f51AF154817C3EF2C827B1;
    address private L2_DEFAULT_LIBRARY = 0xCb78eEfd5fD0fA8DDB0C5e3FbC3bDcCba545Ae67;

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

        // Users addresses are available across forks
        vm.makePersistent(beekeeper);
        vm.makePersistent(jani);
        vm.makePersistent(gameAdmin);
        vm.makePersistent(alfaHunter);
        vm.makePersistent(bera);
        vm.makePersistent(clown);

        vm.selectFork(L1_FORK_ID);

        // Fund Users
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

        // Chainlink setup (L1) HOPEFULLY unsused
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

        hibernationDenL1 = new HibernationDen(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        portalL1 =
        new HoneyJarPortal(50000, L1_LZ_ENDPOINT, address(honeyJar),address(hibernationDenL1), address(gameRegistry));

        mintConfig = HibernationDen.MintConfig({
            maxClaimableHoneyJar: maxClaimableHoneyJar,
            honeyJarPrice_ERC20: MINT_PRICE_ERC20, // 9.9 OHM
            honeyJarPrice_ETH: MINT_PRICE_ETH // 0.099 eth
        });

        // Set up on VRF site
        vrfCoordinator.addConsumer(subId, address(hibernationDenL1));

        hibernationDenL1.initialize(HibernationDen.VRFConfig("", subId, 3, 10000000), mintConfig);
        gameRegistry.registerGame(address(hibernationDenL1));

        /**
         *   Generate roots
         */
        gateData = new bytes32[](3);
        gateData[0] = createNode(alfaHunter, 2);
        gateData[1] = createNode(bera, 3);
        gateData[2] = createNode(clown, 3);
        gateRoot = merkleLib.getRoot(gateData);
        // L1 doesn't need gates

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

        bundleId = hibernationDenL1.addBundle(L2_CHAIN_ID, checkpoints, tokenAddresses, tokenIDs, isERC1155s);

        erc721.approve(address(hibernationDenL1), NFT_ID);
        erc721.approve(address(hibernationDenL1), NFT_ID + 1);
        erc721.approve(address(hibernationDenL1), NFT_ID + 2);
        erc721.approve(address(hibernationDenL1), NFT_ID + 3);
        erc721.approve(address(hibernationDenL1), NFT_ID + 4);

        erc1155.setApprovalForAll(address(hibernationDenL1), true);

        gameRegistry.startGame(address(hibernationDenL1));
        hibernationDenL1.setPortal(address(portalL1));
        vm.stopPrank();

        ////////////// L2 Setup  ////////////////

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

        // Chainlink setup (L2) // This should be used
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
        // use BundleId from l1.addBundle()
        gatekeeperL2.addGate(bundleId, gateRoot, maxClaimableHoneyJar + 1, 0);

        hibernationDenL2 = new HibernationDen(
            address(vrfCoordinatorL2),
            address(gameRegistryL2),
            address(honeyJarL2),
            address(paymentTokenL2),
            address(gatekeeperL2),
            address(jani),
            address(beekeeper),
            honeyJarShare
        );

        vrfCoordinatorL2.addConsumer(subIdL2, address(hibernationDenL2));

        portalL2 =
        new HoneyJarPortal(100000, L2_LZ_ENDPOINT, address(honeyJarL2),address(hibernationDenL2), address(gameRegistryL2));
        hibernationDenL2.setPortal(address(portalL2));

        // Set trusted remotes
        vm.selectFork(L1_FORK_ID);
        portalL1.setTrustedRemote(
            portalL1.lzChainId(L2_CHAIN_ID), abi.encodePacked(address(portalL2), address(portalL1))
        );

        vm.selectFork(L2_FORK_ID);
        portalL2.setTrustedRemote(
            portalL2.lzChainId(L1_CHAIN_ID), abi.encodePacked(address(portalL1), address(portalL2))
        );
    }

    function testCrossChainIntegration() public {
        (address[] memory tokenAddresses,,) = _getBundleInput();

        vm.selectFork(L1_FORK_ID);
        vm.recordLogs();

        vm.prank(gameAdmin);
        hibernationDenL1.puffPuffPassOut{value: 1 ether}(bundleId);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        lzHelper.help(
            L2_LZ_ENDPOINT,
            L2_DEFAULT_LIBRARY,
            100000,
            0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82,
            L2_FORK_ID,
            logs
        );

        // Assuming the claiming flow works the same from below. Go to GeneralMint
        vm.warp(block.timestamp + 72 hours);

        vm.startPrank(alfaHunter);
        // hibernationDenL1.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5); Fails as expected
        hibernationDenL2.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        vm.startPrank(bera);
        hibernationDenL2.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        vm.startPrank(clown);
        hibernationDenL2.mekHoneyJarWithETH{value: MINT_PRICE_ETH * 5}(bundleId, 5);
        vm.stopPrank();

        // Get winnors
        vrfCoordinator.fulfillRandomWords(1, address(hibernationDenL2));
        HibernationDen.SlumberParty memory party = hibernationDenL2.getSlumberParty(bundleId);
        assertEq(party.fermentedJarsFound, true, "fermentedJarsFound should be true");
        assertEq(party.assetChainId, L1_CHAIN_ID, "assetChainId is incorrect");
        assertEq(party.mintChainId, L2_CHAIN_ID, "mintChainId is incorrect");
        assertEq(party.fermentedJars.length, tokenAddresses.length, "fermented jars != num sleepers");

        vm.recordLogs();
        logs = vm.getRecordedLogs();
        lzHelper.help(0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab, 100000, 421613, logs);
        vm.stopPrank();

        // Players **MUST** bridge their winning NFT to the assetChainId in order to wake sleeper.

        // Test out a particular winner
        uint256 fermentedJarId = party.fermentedJars[0].id;
        address winner = honeyJar.ownerOf(fermentedJarId);

        vm.startPrank(winner);
        // hibernationDenL2.wakeSleeper(bundleId, fermentedJarId);  This fails like it should
        hibernationDenL1.wakeSleeper(bundleId, fermentedJarId);
    }

    function _getBundleInput()
        internal
        view
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

    function _validateWinners() internal {
        HibernationDen.SlumberParty memory party = hibernationDenL1.getSlumberParty(bundleId);
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
            hibernationDenL1.wakeSleeper(bundleId, fermentedJar.id); // Validate an NFT transfer occured.
            vm.stopPrank();
            assertEq(erc721.balanceOf(winner) + erc1155.balanceOf(winner, SFT_ID), alreadyWon + 1);
        }
    }

    receive() external payable {}
}
