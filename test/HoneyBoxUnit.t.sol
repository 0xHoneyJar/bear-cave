// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "test/mocks/MockERC1155.sol";
import "test/mocks/MockERC20.sol";
import "test/mocks/MockVRFCoordinator.sol";
import "test/utils/UserFactory.sol";
import "test/utils/Random.sol";

import "src/HoneyBox.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";

import {console2} from "forge-std/console2.sol";

contract HoneyBoxTest is Test, ERC1155TokenReceiver {
    using Random for uint256;
    using FixedPointMathLib for uint256;
    using Address for address;

    uint256 private constant MAX_RANDOM = 69420782347;
    uint256 private constant MINT_PRICE_ERC20 = 9.9 * 1e9;
    uint256 private constant MINT_PRICE_ETH = 0.099 ether;

    uint32 private maxHoneycomb = 4;
    uint256 private honeyJarShare = 2233 * 1e14; // In WAD (.2233)

    uint256 private bearId;
    MockERC1155 private erc1155;
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
        bearId = MAX_RANDOM.randomFromMax();
        erc1155 = new MockERC1155();
        paymentToken = new MockERC20("OHM", "OHM", 9);
        paymentToken.mint(address(this), MINT_PRICE_ERC20); // Only mint enough for 1 honeys

        beekeeper = payable(makeAddr("beekeeper"));
        jani = payable(makeAddr("definitelyNotJani"));
        anotherUser = makeAddr("ngmi");

        // Mint a bear to us
        erc1155.mint(address(this), bearId, 1, "");

        // Game Registry
        gameRegistry = new GameRegistry();
        gameRegistry.setBeekeeper(beekeeper);
        gameRegistry.setJani(jani);

        // Chainlink setup
        vrfCoordinator = new MockVRFCoordinator();
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        // deploy HoneyJar
        honeyJar = new HoneyJar(address(gameRegistry));

        // MintConfig
        mintConfig.maxHoneycomb = maxHoneycomb;
        mintConfig.maxClaimableHoneycomb = 5;
        mintConfig.honeyJarPrice_ERC20 = MINT_PRICE_ERC20;
        mintConfig.honeyJarPrice_ETH = MINT_PRICE_ETH;

        gatekeeper = new Gatekeeper(address(gameRegistry));

        // Deploy the honeyBox
        honeyBox = new HoneyBox(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(erc1155),
            address(paymentToken),
            address(gatekeeper),
            honeyJarShare
        );

        honeyBox.setSubId(subId);
        honeyBox.setJani(jani);
        honeyBox.setBeeKeeper(beekeeper);
        honeyBox.initialize(bytes32(""), subId, jani, beekeeper, mintConfig);

        vrfCoordinator.addConsumer(subId, address(honeyBox));
        gameRegistry.registerGame(address(honeyBox));
        gameRegistry.startGame(address(honeyBox));
    }

    function testFailBearcave_alreadyInitialized() public {
        honeyBox.initialize(bytes32(""), 1, address(1), address(2), mintConfig);
    }

    // ============= Hibernating Bear ==================== //

    function testFailHibernateBear_noPermissions() public {
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "wtf you didn't mint a bear");
        erc1155.mint(beekeeper, bearId + 1, 1, "");

        // Beekeeper is unauthorized
        vm.startPrank(beekeeper);
        _hibernateBear(bearId);
    }

    function testHibernateBear() public {
        erc1155.setApprovalForAll(address(honeyBox), true);
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "wtf you didn't mint a bear");
        honeyBox.hibernateBear(bearId);
        assertEq(erc1155.balanceOf(address(this), bearId), 0, "wtf you didn't hibernate it");
        assertEq(erc1155.balanceOf(address(honeyBox), bearId), 1, "wtf the bear got lost");
    }

    // ============= Meking Honeycombs ==================== //

    function testFailMekHoney_notInitialized() public {
        honeyBox.mekHoneyJarWithERC20(69, 1);
    }

    function testFailMekHoney_noMinterPerms() public {
        _hibernateBear(bearId);

        // Stoping the game revokes minter permissions.
        gameRegistry.stopGame(address(honeyBox));
        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bearId, 1); // Does the contract just eat up the ERC20?
    }

    function testFailMekHoney_wrongBearId() public {
        _hibernateBear(bearId);

        honeyBox.mekHoneyJarWithERC20(69, 1);
    }

    function testFailMekHoney_noETH() public {
        _hibernateBear(bearId);

        honeyBox.mekHoneyJarWithEth(bearId, 1);
    }

    function testFailMekHoney_noMoneys() public {
        _hibernateBear(bearId);

        paymentToken.burn(address(this), MINT_PRICE_ERC20);

        assertEq(paymentToken.balanceOf(address(this)), 0, "how do you still have monies?");
        assertEq(paymentToken.allowance(address(this), address(honeyBox)), 0, "bear cave can't take ur monies");
        honeyBox.mekHoneyJarWithERC20(bearId, 1);
    }

    function testmekHoneyJarWithERC20() public {
        _hibernateBear(bearId);

        assertEq(honeyJar.balanceOf(address(this)), 0, "how do you already have honey?");
        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20);
        assertGe(paymentToken.balanceOf(address(this)), MINT_PRICE_ERC20, "You dont have enough ohms");

        uint256 honeyId = honeyBox.mekHoneyJarWithERC20(bearId, 1);
        assertEq(honeyJar.balanceOf(address(this)), 1, "uhh you don't have honey");
        assertEq(honeyJar.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function testMekManyHoneycombWithERC20() public {
        _hibernateBear(bearId);
        uint32 mintAmount = 500;
        paymentToken.mint(address(this), MINT_PRICE_ERC20 * mintAmount);
        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20 * mintAmount);

        // increase mint limits
        gameRegistry.stopGame(address(honeyBox));
        honeyBox.setMaxHoneycomb(mintAmount + 1);
        gameRegistry.startGame(address(honeyBox));

        honeyBox.mekHoneyJarWithERC20(bearId, mintAmount);

        assertEq(honeyJar.balanceOf(address(this)), mintAmount, "mint amount doesn't match honeyJars");
    }

    function testMekHoneyJarWithETH() public {
        _hibernateBear(bearId);

        // Will make a call to honeyBox.mekHoneyJarWithETH(bearId).
        bytes memory request = abi.encodeWithSelector(HoneyBox.mekHoneyJarWithEth.selector, bearId, 2);
        bytes memory response = address(honeyBox).functionCallWithValue(request, MINT_PRICE_ETH * 2);
        uint256 honeyId = abi.decode(abi.encodePacked(new bytes(32 - response.length), response), (uint256)); // Converting bytes -- uint256

        assertEq(honeyJar.balanceOf(address(this)), 2, "uhh you don't have honey");
        assertEq(honeyJar.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function _simulateVRF(uint256 bearId_) private {
        // Gotta manually do this to simulate VRF working.
        for (uint256 i = 0; i < 5; ++i) {
            if (honeyBox.rng(i) != bearId_) continue;
            vrfCoordinator.fulfillRandomWords(i, address(honeyBox));
            break;
        }
    }

    function testFindSpecialHoney() public {
        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        assertEq(honeyBox.getBear(bearId).specialHoneycombFound, true, "special honey is not found");
    }

    // ============= Waking Bear ==================== //

    function testFailWakeBear_noBear() public {
        // Will give the same error as "not enough honeyJars"
        honeyBox.wakeBear(69);
    }

    function testFailWakeBear_notEnoughHoney() public {
        // Same as the bear is sleeping
        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bearId, 1);

        honeyBox.wakeBear(bearId);
    }

    function testFailWakeBear_wrongUser() public {
        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        vm.prank(anotherUser);
        honeyBox.wakeBear(bearId);
    }

    function testFailWakeBear_allHoneyJarNoVRF() public {
        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);
        honeyBox.wakeBear(bearId);
    }

    function testWakeBear() public {
        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        honeyBox.wakeBear(bearId);
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    function testWorks() public {
        assertTrue(true, "fuckin goteeem. r u even reading this?");
    }

    function testTwoSleepingBears() public {
        //  can make this test more robust by validating the mekHoneyJarWithERC20/findSpecial honey outputs.
        uint256 secondBearId = 69420;
        erc1155.mint(address(this), secondBearId, 1, "");

        _hibernateBear(bearId);
        _hibernateBear(secondBearId);

        paymentToken.approve(address(honeyBox), maxHoneycomb * MINT_PRICE_ERC20 * 2);
        _makeMultipleHoney(bearId, maxHoneycomb);
        _makeMultipleHoney(secondBearId, maxHoneycomb);

        _simulateVRF(bearId);
        _simulateVRF(secondBearId);

        honeyBox.wakeBear(bearId);
        honeyBox.wakeBear(secondBearId);

        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    // ============= Bear Pouch ==================== //

    function testDistributeWithMint_ERC20() public {
        // initial conditions
        assertEq(paymentToken.balanceOf(beekeeper), 0, "init: not zero");
        assertEq(paymentToken.balanceOf(jani), 0, "init: not zero");

        _hibernateBear(bearId);

        paymentToken.approve(address(honeyBox), MINT_PRICE_ERC20);
        honeyBox.mekHoneyJarWithERC20(bearId, 1);

        uint256 beekeeperExpected = MINT_PRICE_ERC20.mulWadUp(honeyJarShare);

        assertEq(paymentToken.balanceOf(beekeeper), beekeeperExpected, "beekeper not paid the right amount");
        assertEq(paymentToken.balanceOf(jani), MINT_PRICE_ERC20 - beekeeperExpected, "jani not paid the right amount");
    }

    function testDistributeWithMint_ETH() public {
        // initial conditions
        assertEq(beekeeper.balance, 0, "init: not zero");
        assertEq(jani.balance, 0, "init: not zero");

        _hibernateBear(bearId);

        // Will make a call to honeyBox.mekHoneyJarWithETH(bearId).
        bytes memory request = abi.encodeWithSelector(HoneyBox.mekHoneyJarWithEth.selector, bearId, 1);
        address(honeyBox).functionCallWithValue(request, MINT_PRICE_ETH);

        uint256 beekeeperExpected = MINT_PRICE_ETH.mulWadUp(honeyJarShare);

        assertEq(beekeeper.balance, beekeeperExpected, "beekeper not paid the right amount");
        assertEq(jani.balance, MINT_PRICE_ETH - beekeeperExpected, "jani not paid the right amount");
    }

    function testClaimHoneycomb() public {
        // initial conditions

        gatekeeper.addGate(bearId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 0);
        gatekeeper.addGate(bearId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 1);
        gatekeeper.addGate(bearId, 0x4135c2b0e6d88c1cf3fbb9a75f6a8695737fb5e3bb0efc09d95eeb7fdec2b948, 6969, 2);
        _hibernateBear(bearId);

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

        (bool enabled, uint8 stageIndex, uint32 claimedCount, uint32 maxClaimable, bytes32 gateRoot, uint256 activeAt) =
            gatekeeper.tokenToGates(bearId, 0);

        vm.prank(address(0x79092A805f1cf9B0F5bE3c5A296De6e51c1DEd34));
        honeyBox.claim(bearId, 0, 2, proof); // results in 2

        // honeyBox.claim(bearId, 0, 2, proof); reverts
    }

    // ============= Claiming will be an integration test  ==================== //

    /**
     * Internal Helper methods
     */
    function _makeMultipleHoney(uint256 _bearId, uint256 _amount) internal {
        paymentToken.mint(address(this), MINT_PRICE_ERC20 * _amount);
        honeyBox.mekHoneyJarWithERC20(_bearId, _amount);
    }

    function _hibernateBear(uint256 bearId_) internal {
        erc1155.setApprovalForAll(address(honeyBox), true);
        honeyBox.hibernateBear(bearId_);
        vm.warp(block.timestamp + 73 hours); // Test in the public mint area
    }
}
