// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockVRFCoordinator} from "test/mocks/MockVRFCoordinator.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {UserFactory} from "test/utils/UserFactory.sol";
import {Random} from "test/utils/Random.sol";

import {HoneyBox} from "src/HoneyBox.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {CrossChainTHJ} from "src/CrossChainTHJ.sol";

import {console2} from "forge-std/console2.sol";

contract HoneyBoxUnitTest is Test, ERC1155TokenReceiver, ERC721TokenReceiver {
    using FixedPointMathLib for uint256;
    using Address for address;

    uint256 private constant MINT_PRICE_ERC20 = 9.9 * 1e9;
    uint256 private constant MINT_PRICE_ETH = 0.099 ether;

    uint32 private maxHoneyJar = 4;
    uint256 private honeyJarShare = 2233 * 1e14; // In WAD (.2233)

    uint8 private bundleId;
    MockERC1155 private erc1155;
    MockERC721 private erc721;
    MockERC20 private paymentToken;
    Gatekeeper private gatekeeper;

    // Users
    address payable private beekeeper;
    address payable private jani;
    address private anotherUser;

    GameRegistry private gameRegistry;
    HoneyBox private honeyBox;
    HoneyBox.MintConfig private mintConfig;
    HoneyJar private honeyJar;

    //Chainlink setup
    MockVRFCoordinator private vrfCoordinator;
    uint96 private constant FUND_AMOUNT = 1 * 10 ** 18;

    // Initialize the test suite
    function setUp() public {
        // Deploy the ERC1155 token contract
        erc1155 = new MockERC1155();
        erc721 = new MockERC721("OOGA", "BOOGA");
        paymentToken = new MockERC20("OHM", "OHM", 9);
        paymentToken.mint(address(this), MINT_PRICE_ERC20); // Only mint enough for 1 honeys

        beekeeper = payable(makeAddr("beekeeper"));
        jani = payable(makeAddr("definitelyNotJani"));
        anotherUser = makeAddr("ngmi");

        // Mint NFTs to us
        erc1155.mint(address(this), 0, 1, "");
        erc721.mint(address(this), 0);

        // Game Registry
        gameRegistry = new GameRegistry();
        gameRegistry.setBeekeeper(beekeeper);
        gameRegistry.setJani(jani);

        // Chainlink setup
        vrfCoordinator = new MockVRFCoordinator();
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        // deploy HoneyJar
        honeyJar = new HoneyJar(address(this), address(gameRegistry), 0, 1e9);

        // MintConfig
        mintConfig = HoneyBox.MintConfig({
            maxHoneyJar: maxHoneyJar,
            maxClaimableHoneyJar: 5,
            honeyJarPrice_ERC20: MINT_PRICE_ERC20, // 9.9 OHM
            honeyJarPrice_ETH: MINT_PRICE_ETH // 0.099 eth
        });

        // Gatekeeper
        gatekeeper = new Gatekeeper(address(gameRegistry));

        // Deploy the honeyBox
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

        vrfCoordinator.addConsumer(subId, address(honeyBox));
        honeyBox.initialize(HoneyBox.VRFConfig("", subId, 3, 10000000), mintConfig);

        gameRegistry.registerGame(address(honeyBox));
        gameRegistry.startGame(address(honeyBox));
        bundleId = _addBundle(0);

        // HoneyBox needs at least one gate to function.
        gatekeeper.addGate(bundleId, 0x00000000000000, 6969, 0);
    }

    function testFail_alreadyInitialized() public {
        honeyBox.initialize(HoneyBox.VRFConfig("", 1, 3, 10000000), mintConfig);
    }

    // ============= Hibernating  ==================== //

    function testFail_unauthorized() public {
        assertEq(erc1155.balanceOf(address(this), bundleId), 1, "wtf you didn't mint a bear");
        erc1155.mint(beekeeper, bundleId + 1, 1, "");

        // Beekeeper is unauthorized
        vm.startPrank(beekeeper);
        _puffPuffPassOut(bundleId);
    }

    function testFailPuffPuffPassOut_NoBundle() public {
        honeyBox.puffPuffPassOut(bundleId);
    }

    function testAddBundle() public {
        _addBundle(0);
    }

    function testChainId() public {
        bundleId = _addBundle(0);
        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        assertEq(party.mintChainId, block.chainid);
        assertEq(party.assetChainId, block.chainid);
    }

    function testAddToParty() public {
        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        uint256 numSleepers = party.sleepoors.length;

        // Add random addr
        HoneyBox.SleepingNFT memory newSleeper;
        newSleeper.isERC1155 = false;
        newSleeper.tokenId = 1;
        newSleeper.tokenAddress = makeAddr("token");

        honeyBox.addToParty(party.bundleId, newSleeper, false);

        // Add a real erc1155
        MockERC1155 newToken = new MockERC1155();
        newToken.mint(address(this), 1, 1, "");
        newSleeper.isERC1155 = true;
        newSleeper.tokenId = 1;
        newSleeper.tokenAddress = address(newToken);
        newToken.setApprovalForAll(address(honeyBox), true); // fails without approvals

        honeyBox.addToParty(party.bundleId, newSleeper, true);

        party = honeyBox.getSlumberParty(bundleId);
        assertEq(party.sleepoors.length, numSleepers + 2);
    }

    // ============= Meking HoneyJar ==================== //

    function testFailMekHoney_notSleeping() public {
        honeyBox.mekHoneyJarWithERC20(bundleId, 1);
    }

    function testFailMekHoney_noMinterPerms() public {
        _puffPuffPassOut(bundleId);

        // Stoping the game revokes minter permissions.
        gameRegistry.stopGame(address(honeyBox));
        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 1); // Does the contract just eat up the ERC20?
    }

    function testFailMekHoney_wrongBundleId() public {
        _puffPuffPassOut(bundleId);

        honeyBox.mekHoneyJarWithERC20(69, 1);
    }

    function testFailMekHoney_noETH() public {
        _puffPuffPassOut(bundleId);

        honeyBox.mekHoneyJarWithETH(bundleId, 1);
    }

    function testFailMekHoney_noMoneys() public {
        _puffPuffPassOut(bundleId);

        paymentToken.burn(address(this), MINT_PRICE_ERC20);

        assertEq(paymentToken.balanceOf(address(this)), 0, "how do you still have monies?");
        assertEq(paymentToken.allowance(address(this), address(honeyBox)), 0, "bear cave can't take ur monies");
        honeyBox.mekHoneyJarWithERC20(bundleId, 1);
    }

    function testmekHoneyJarWithERC20() public {
        _puffPuffPassOut(bundleId);

        assertEq(honeyJar.balanceOf(address(this)), 0, "how do you already have honey?");
        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20);
        assertGe(paymentToken.balanceOf(address(this)), MINT_PRICE_ERC20, "You dont have enough ohms");

        uint256 honeyId = honeyBox.mekHoneyJarWithERC20(bundleId, 1);
        assertEq(honeyJar.balanceOf(address(this)), 1, "uhh you don't have honey");
        assertEq(honeyJar.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function testMekManyHoneyJarWithERC20() public {
        _puffPuffPassOut(bundleId);
        uint32 mintAmount = 500;
        paymentToken.mint(address(this), MINT_PRICE_ERC20 * mintAmount);
        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20 * mintAmount);

        // increase mint limits
        gameRegistry.stopGame(address(honeyBox));
        honeyBox.setMaxHoneyJar(mintAmount + 1);
        gameRegistry.startGame(address(honeyBox));

        honeyBox.mekHoneyJarWithERC20(bundleId, mintAmount);

        assertEq(honeyJar.balanceOf(address(this)), mintAmount, "mint amount doesn't match honeyJars");
    }

    function testMekHoneyJarWithETH() public {
        _puffPuffPassOut(bundleId);

        // Will make a call to honeyBox.mekHoneyJarWithETH(bundleId).
        bytes memory request = abi.encodeWithSelector(HoneyBox.mekHoneyJarWithETH.selector, bundleId, 2);
        bytes memory response = address(honeyBox).functionCallWithValue(request, MINT_PRICE_ETH * 2);
        uint256 honeyId = abi.decode(abi.encodePacked(new bytes(32 - response.length), response), (uint256)); // Converting bytes -- uint256

        assertEq(honeyJar.balanceOf(address(this)), 2, "uhh you don't have honey");
        assertEq(honeyJar.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function _simulateVRF(uint256 bundleId_) private {
        // Loop through potential requestIds starting at 1 to find one corresponding to bundle
        for (uint256 i = 1; i < 5; ++i) {
            if (honeyBox.rng(i) != bundleId_) continue;
            vrfCoordinator.fulfillRandomWords(i, address(honeyBox));
            break;
        }
    }

    function testFindFermentedHoney() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);

        _simulateVRF(bundleId);
        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        assertEq(party.fermentedJarsFound, true, "Fermented Jar is not found");
    }

    // ============= Waking Slumber Party ==================== //

    function testFailOpenHotBox() public {
        // NFT doens't exist
        honeyBox.wakeSleeper(bundleId, 0);
    }

    function testFailWakeBear_notEnoughHoney() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 1);

        honeyBox.wakeSleeper(bundleId, 0);
    }

    function testFailOpenHotBox_wrongUser() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);

        _simulateVRF(bundleId);

        vm.prank(anotherUser);
        honeyBox.wakeSleeper(bundleId, 0);
    }

    function testFailWakeWithWrongJar() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);

        _simulateVRF(bundleId);

        honeyBox.wakeSleeper(bundleId, 0);
    }

    function testFailOpenHotBox_allHoneyJarNoVRF() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);
        honeyBox.wakeSleeper(bundleId, 0); // SpecialHoneyJar not found
    }

    function testWakeParty() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);

        _simulateVRF(bundleId);

        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        _wakeAll(bundleId, party.fermentedJars);

        assertEq(erc1155.balanceOf(address(this), 0), 1, "the bear didn't wake up");
        assertEq(erc721.balanceOf(address(this)), 1, "the bear didn't wake up");
    }

    function testFailWakePartyTwice() public {
        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20);
        _makeMultipleHoney(bundleId, maxHoneyJar);

        _simulateVRF(bundleId);

        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        _wakeAll(bundleId, party.fermentedJars);
        _wakeAll(bundleId, party.fermentedJars);
    }

    function _wakeAll(uint8 bundleId_, HoneyBox.FermentedJar[] memory jars) internal {
        for (uint256 i = 0; i < jars.length; i++) {
            honeyBox.wakeSleeper(bundleId_, jars[i].id);
        }
    }

    function testWorks() public {
        assertTrue(true, "fuckin goteeem. r u even reading this?");
    }

    function testTwoSlumberParties() public {
        //  can make this test more robust by validating the mekHoneyJarWithERC20/findSpecial honey outputs.
        uint8 secondBundleId = _addBundle(2);
        gatekeeper.addGate(secondBundleId, 0x00000000000000, 6969, 0);

        erc1155.mint(address(this), 2, 1, "");
        erc721.mint(address(this), 2);

        _puffPuffPassOut(bundleId);
        _puffPuffPassOut(secondBundleId);

        paymentToken.approve(address(honeyBox), maxHoneyJar * MINT_PRICE_ERC20 * 2);
        _makeMultipleHoney(bundleId, maxHoneyJar);
        _makeMultipleHoney(secondBundleId, maxHoneyJar);

        _simulateVRF(bundleId);
        _simulateVRF(secondBundleId);

        HoneyBox.SlumberParty memory party1 = honeyBox.getSlumberParty(bundleId);
        HoneyBox.SlumberParty memory party2 = honeyBox.getSlumberParty(secondBundleId);

        _wakeAll(bundleId, party1.fermentedJars);
        _wakeAll(secondBundleId, party2.fermentedJars);

        assertEq(erc1155.balanceOf(address(this), 0), 1, "the bear didn't wake up");
        assertEq(erc1155.balanceOf(address(this), 2), 1, "the bear didn't wake up");
        assertEq(erc721.balanceOf(address(this)), 2, "the Nft didn't wake up");
    }

    // ============= Bear Pouch ==================== //

    function testDistributeWithMint_ERC20() public {
        // initial conditions
        assertEq(paymentToken.balanceOf(beekeeper), 0, "init: not zero");
        assertEq(paymentToken.balanceOf(jani), 0, "init: not zero");

        _puffPuffPassOut(bundleId);

        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bundleId, 1);

        uint256 beekeeperExpected = MINT_PRICE_ERC20.mulWadUp(honeyJarShare);

        assertEq(paymentToken.balanceOf(beekeeper), beekeeperExpected, "beekeper not paid the right amount");
        assertEq(paymentToken.balanceOf(jani), MINT_PRICE_ERC20 - beekeeperExpected, "jani not paid the right amount");
    }

    function testDistributeWithMint_ETH() public {
        // initial conditions
        assertEq(beekeeper.balance, 0, "init: not zero");
        assertEq(jani.balance, 0, "init: not zero");

        _puffPuffPassOut(bundleId);

        // Will make a call to honeyBox.mekHoneyJarWithETH(bundleId).
        bytes memory request = abi.encodeWithSelector(HoneyBox.mekHoneyJarWithETH.selector, bundleId, 1);
        address(honeyBox).functionCallWithValue(request, MINT_PRICE_ETH);

        uint256 beekeeperExpected = MINT_PRICE_ETH.mulWadUp(honeyJarShare);

        assertEq(beekeeper.balance, beekeeperExpected, "beekeper not paid the right amount");
        assertEq(jani.balance, MINT_PRICE_ETH - beekeeperExpected, "jani not paid the right amount");
    }

    function testClaimHoneyJar() public {
        // initial conditions

        gatekeeper.addGate(bundleId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 0);
        gatekeeper.addGate(bundleId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 1);
        gatekeeper.addGate(bundleId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 2);
        _puffPuffPassOut(bundleId);

        bytes32[] memory proof = new bytes32[](11);
        proof[0] = 0x2cab18c6136eee630c87d06ee09d821becc2ab5de6884ec207caa6efbf106dfc;
        proof[1] = 0x4050c58f7f1b02c5ab26124e25dbee16bdd575ae58f48de5caca4819b669db38;
        proof[2] = 0x6ecb27ca41e2b2a9984fd4b44f01652a1ea666deb47158aee4f667c02c0d6331;
        proof[3] = 0x84f50225cb4b0751536690e95944e89deeb058bbf6a9a93a0b8c0a389262ff1a;
        proof[4] = 0x9dcde3885e47f382fddc73d7cc5b992245e718e837309d9585d9dffa1dbfebe6;
        proof[5] = 0xef2ef4e06ee9416d61bdc94af8443294afd09dc52024f6684f90d7a53a492fa4;
        proof[6] = 0xf23a29367916e77c2d0c4cf1028644ccbff08fb01528ad364b43783b1ac48e64;
        proof[7] = 0xf511c06624aa37de81ca3636dc5fb1f07fc4c899d178b71ef253219f3854ae95;
        proof[8] = 0xb281427fdfe85dd2596444f48f541fe1b67abc9cf017046d62f557be67bb0c2a;
        proof[9] = 0x1bd731646c7f0b4aeca11b7bfe2ccbea48990cfded41b82da665f25ecdcb6f6f;
        proof[10] = 0x26f092416571d53df969f9c8bc85a0fdc197603b71ee8dc78f587751b3972e22;

        // The first gate is a blank one, skip it for this test.
        (bool enabled, uint8 stageIndex, uint32 claimedCount, uint32 maxClaimable, bytes32 gateRoot, uint256 activeAt) =
            gatekeeper.tokenToGates(bundleId, 1);

        vm.prank(address(0x79092A805f1cf9B0F5bE3c5A296De6e51c1DEd34));
        honeyBox.claim(bundleId, 1, 2, proof); // results in 2

        // honeyBox.claim(bundleId, 0, 2, proof); reverts
    }

    ////////////////////////////////////////
    ////////    Cross Chain Tests //////////
    ////////////////////////////////////////

    function testDiffChainId() public {
        uint256 wrongChainId = 123;
        uint256 tokenId = 123;
        bundleId = _addBundleForChain(wrongChainId, tokenId);

        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(bundleId);
        assertEq(party.mintChainId, wrongChainId);
        assertEq(party.assetChainId, block.chainid);
    }

    function testFailMekHoneyJar_diffChainId() public {
        uint256 wrongChainId = 123;
        uint256 tokenId = 123;
        erc721.mint(address(this), tokenId);

        bundleId = _addBundleForChain(wrongChainId, tokenId);
        _puffPuffPassOut(bundleId);

        // Errors out with #invalid chain
        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH}(bundleId, 1);
    }

    function testFailStartGame_bundleAlreadyExists() public {
        CrossChainTHJ.CrossChainBundleConfig memory config;
        // Give this address portal role in order to call method
        gameRegistry.grantRole("PORTAL", address(this));
        config.bundleId = bundleId;
        config.numSleepers = 8;
        honeyBox.startGame(block.chainid, config);
    }

    function testStartGameXChain() public {
        // simulates getting a message saying "start the game"
        CrossChainTHJ.CrossChainBundleConfig memory config;
        // Give this address portal role in order to call method
        gameRegistry.grantRole("PORTAL", address(this));
        config.bundleId = bundleId + 1;
        config.numSleepers = 8;

        gatekeeper.addGate(config.bundleId, bytes32(0), 6969, 0);
        honeyBox.startGame(block.chainid, config);
        vm.warp(block.timestamp + 72 hours);

        honeyBox.mekHoneyJarWithETH{value: MINT_PRICE_ETH * maxHoneyJar}(config.bundleId, maxHoneyJar);

        _simulateVRF(config.bundleId);

        HoneyBox.SlumberParty memory party = honeyBox.getSlumberParty(config.bundleId);
        assertEq(party.fermentedJarsFound, true, "expected fermentedJarsFound");
        assertEq(party.sleepoors.length, config.numSleepers);

        // This call should fail because its not a real NFT
        // honeyBox.wakeSleeper(config.bundleId, party.fermentedJars[0].id);
    }

    // ============= Claiming will be an integration test  ==================== //

    /**
     * Internal Helper methods
     */
    function _makeMultipleHoney(uint8 _bundleId, uint256 _amount) internal {
        paymentToken.mint(address(this), MINT_PRICE_ERC20 * _amount);
        honeyBox.mekHoneyJarWithERC20(_bundleId, _amount);
    }

    function _puffPuffPassOut(uint8 bundleId_) internal {
        erc1155.setApprovalForAll(address(honeyBox), true);
        erc721.setApprovalForAll(address(honeyBox), true);

        honeyBox.puffPuffPassOut(bundleId_);
        vm.warp(block.timestamp + 73 hours); // Test in the public mint area
    }

    function _addBundle(uint256 tokenId_) internal returns (uint8) {
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(erc1155);
        tokenAddresses[1] = address(erc721);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId_;
        tokenIds[1] = tokenId_;
        bool[] memory isERC1155 = new bool[](2);
        isERC1155[0] = true;
        isERC1155[1] = false;
        return honeyBox.addBundle(block.chainid, tokenAddresses, tokenIds, isERC1155);
    }

    function _addBundleForChain(uint256 chainId_, uint256 tokenId_) internal returns (uint8) {
        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = address(erc721);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId_;
        bool[] memory isERC1155 = new bool[](1);
        isERC1155[0] = false;

        return honeyBox.addBundle(chainId_, tokenAddresses, tokenIds, isERC1155);
    }
}
