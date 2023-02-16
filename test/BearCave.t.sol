// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./mocks/MockERC1155.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVRFCoordinator.sol";
import "./utils/UserFactory.sol";
import "./utils/Random.sol";

import "src/BearCave.sol";
import {HoneyComb} from "src/HoneyComb.sol";
import {GameRegistry} from "src/GameRegistry.sol";

import {console2} from "forge-std/console2.sol";

// TODO: test bearCave claiming process
contract BearCaveTest is Test, ERC1155TokenReceiver {
    using Random for uint256;
    using FixedPointMathLib for uint256;
    using Address for address;

    uint256 private constant MAX_RANDOM = 69420782347;
    uint256 private constant MINT_PRICE_ERC20 = 9.9 * 1e9;
    uint256 private constant MINT_PRICE_ETH = 0.099 ether;

    uint32 private maxHoneycomb = 4;
    uint256 private honeycombShare = 2233 * 1e14; // In WAD (.2233)

    uint256 private bearId;
    MockERC1155 private erc1155;
    MockERC20 private paymentToken;

    // Users
    address payable private beekeeper;
    address payable private jani;
    address private anotherUser;

    GameRegistry private gameRegistry;
    BearCave private bearCave;
    IBearCave.MintConfig private mintConfig;
    HoneyComb private honeycomb;

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

        // deploy HoneyComb
        honeycomb = new HoneyComb(address(gameRegistry));

        // MintConfig
        mintConfig.maxHoneycomb = maxHoneycomb;
        mintConfig.maxClaimableHoneycomb = 0; // TODO
        mintConfig.honeycombPrice_ERC20 = MINT_PRICE_ERC20;
        mintConfig.honeycombPrice_ETH = MINT_PRICE_ETH;

        // Deploy the bearCave
        bearCave =
        new BearCave(address(vrfCoordinator), address(gameRegistry), address(honeycomb), address(erc1155), address(paymentToken), honeycombShare);
        bearCave.setSubId(subId);
        bearCave.setJani(jani);
        bearCave.setBeeKeeper(beekeeper);
        bearCave.initialize(mintConfig);

        vrfCoordinator.addConsumer(subId, address(bearCave));
        gameRegistry.registerGame(address(bearCave));
        gameRegistry.startGame(address(bearCave));
    }

    function testFailBearcave_alreadyInitialized() public {
        bearCave.initialize(mintConfig);
    }

    // ============= Hibernating Bear ==================== //

    function testFailHibernateBear_noPermissions() public {
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "wtf you didn't mint a bear");
        erc1155.mint(beekeeper, bearId + 1, 1, "");

        // Beekeeper is unauthorized
        vm.startPrank(beekeeper);
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
    }

    function testHibernateBear() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "wtf you didn't mint a bear");
        bearCave.hibernateBear(bearId);
        assertEq(erc1155.balanceOf(address(this), bearId), 0, "wtf you didn't hibernate it");
        assertEq(erc1155.balanceOf(address(bearCave), bearId), 1, "wtf the bear got lost");
    }

    // ============= Meking Honeycombs ==================== //

    function testFailMekHoney_notInitialized() public {
        bearCave.mekHoneyCombWithERC20(69);
    }

    function testFailMekHoney_noMinterPerms() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        // Stoping the game revokes minter permissions.
        gameRegistry.stopGame(address(bearCave));
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        bearCave.mekHoneyCombWithERC20(bearId); // Does the contract just eat up the ERC20?
    }

    function testFailMekHoney_wrongBearId() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        bearCave.mekHoneyCombWithERC20(69);
    }

    function testFailMekHoney_noETH() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        bearCave.mekHoneyCombWithEth(bearId);
    }

    function testFailMekHoney_noMoneys() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.burn(address(this), MINT_PRICE_ERC20);

        assertEq(paymentToken.balanceOf(address(this)), 0, "how do you still have monies?");
        assertEq(paymentToken.allowance(address(this), address(bearCave)), 0, "bear cave can't take ur monies");
        bearCave.mekHoneyCombWithERC20(bearId);
    }

    function testmekHoneyCombWithERC20() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);

        assertEq(honeycomb.balanceOf(address(this)), 0, "how do you already have honey?");
        paymentToken.approve(address(bearCave), MINT_PRICE_ERC20);
        assertGe(paymentToken.balanceOf(address(this)), MINT_PRICE_ERC20, "You dont have enough ohms");

        uint256 honeyId = bearCave.mekHoneyCombWithERC20(bearId);
        assertEq(honeycomb.balanceOf(address(this)), 1, "uhh you don't have honey");
        assertEq(honeycomb.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function testMekHoneyCombWithETH() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);

        // Will make a call to bearCave.mekHoneyCombWithETH(bearId).
        bytes memory request = abi.encodeWithSelector(BearCave.mekHoneyCombWithEth.selector, bearId);
        bytes memory response = address(bearCave).functionCallWithValue(request, MINT_PRICE_ETH);
        uint256 honeyId = abi.decode(abi.encodePacked(new bytes(32 - response.length), response), (uint256)); // Converting bytes -- uint256

        assertEq(honeycomb.balanceOf(address(this)), 1, "uhh you don't have honey");
        assertEq(honeycomb.ownerOf(honeyId), address(this), "You have the wrong honey");
    }

    function _simulateVRF(uint256 bearId_) private {
        // Gotta manually do this to simulate VRF working.
        for (uint256 i = 0; i < 5; ++i) {
            if (bearCave.rng(i) != bearId_) continue;
            vrfCoordinator.fulfillRandomWords(i, address(bearCave));
            break;
        }
    }

    function testFindSpecialHoney() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        assertEq(bearCave.getBear(bearId).specialHoneycombFound, true, "special honey is not found");
    }

    // ============= Waking Bear ==================== //

    function testFailWakeBear_noBear() public {
        // Will give the same error as "not enough honeycombs"
        bearCave.wakeBear(69);
    }

    function testFailWakeBear_notEnoughHoney() public {
        // Same as the bear is sleeping
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        bearCave.mekHoneyCombWithERC20(bearId);

        bearCave.wakeBear(bearId);
    }

    function testFailWakeBear_wrongUser() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        vm.prank(anotherUser);
        bearCave.wakeBear(bearId);
    }

    function testFailWakeBear_allHoneyCombNoVRF() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);
        bearCave.wakeBear(bearId);
    }

    function testWakeBear() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20);
        _makeMultipleHoney(bearId, maxHoneycomb);

        _simulateVRF(bearId);

        bearCave.wakeBear(bearId);
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    function testWorks() public {
        assertTrue(true, "fuckin goteeem. r u even reading this?");
    }

    function testTwoSleepingBears() public {
        // TODO: can make this test more robust by validating the mekHoneyCombWithERC20/findSpecial honey outputs.
        // uint256 secondBearId = MAX_RANDOM.randomFromMax(); // This shit isn't random.
        uint256 secondBearId = 69420;
        erc1155.setApprovalForAll(address(bearCave), true);
        erc1155.mint(address(this), secondBearId, 1, "");

        bearCave.hibernateBear(bearId);
        bearCave.hibernateBear(secondBearId);

        paymentToken.approve(address(bearCave), maxHoneycomb * MINT_PRICE_ERC20 * 2);
        _makeMultipleHoney(bearId, maxHoneycomb);
        _makeMultipleHoney(secondBearId, maxHoneycomb);

        _simulateVRF(bearId);
        _simulateVRF(secondBearId);

        bearCave.wakeBear(bearId);
        bearCave.wakeBear(secondBearId);

        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    // ============= Bear Pouch ==================== //

    function testFailWithdrawFunds_noPerms() public {
        vm.prank(anotherUser);
        bearCave.withdrawERC20();
    }

    function testFailWithdrawFunds_noFunds() public {
        vm.prank(jani);
        bearCave.withdrawERC20();
    }

    function testFailWithdraw_featureToggleOn() public {
        bearCave.setDisitrbuteWithMint(true);
        vm.prank(beekeeper);
        bearCave.withdrawERC20();
    }

    function testWithdrawERC20() public {
        // Setup: reset balances
        paymentToken.burn(address(bearCave), paymentToken.balanceOf(address(bearCave)));
        paymentToken.burn(address(this), paymentToken.balanceOf(address(this)));
        paymentToken.burn(beekeeper, paymentToken.balanceOf(beekeeper));

        uint256 ohmAmount = 10000;

        paymentToken.mint(address(bearCave), ohmAmount);
        assertEq(paymentToken.balanceOf(address(bearCave)), ohmAmount);

        vm.prank(beekeeper);
        uint256 amountLeft = bearCave.withdrawERC20();
        assertEq(amountLeft, 0);

        uint256 beekeeperExpected = ohmAmount.mulWadUp(honeycombShare);

        assertEq(paymentToken.balanceOf(beekeeper), beekeeperExpected);
        assertEq(paymentToken.balanceOf(jani), ohmAmount - beekeeperExpected);
    }

    function testWithdrawETH() public {
        // check initial conditions
        assertEq(beekeeper.balance, 0);
        assertEq(jani.balance, 0);

        uint256 ethAmount = 1 ether;
        vm.deal(address(bearCave), ethAmount);

        uint256 beekeeperExpected = ethAmount.mulWadUp(honeycombShare);
        vm.prank(beekeeper);
        uint256 amountLeft = bearCave.withdrawETH();
        assertEq(amountLeft, 0, "bearcave still has money left in it");

        assertEq(beekeeperExpected, beekeeper.balance);
        assertEq(jani.balance, ethAmount - beekeeperExpected);
    }

    function testDistributeWithMint_ERC20() public {
        // initial conditions
        assertEq(paymentToken.balanceOf(beekeeper), 0, "init: not zero");
        assertEq(paymentToken.balanceOf(jani), 0, "init: not zero");

        bearCave.setDisitrbuteWithMint(true);
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), MINT_PRICE_ERC20);
        bearCave.mekHoneyCombWithERC20(bearId);

        uint256 beekeeperExpected = MINT_PRICE_ERC20.mulWadUp(honeycombShare);

        assertEq(paymentToken.balanceOf(beekeeper), beekeeperExpected, "beekeper not paid the right amount");
        assertEq(paymentToken.balanceOf(jani), MINT_PRICE_ERC20 - beekeeperExpected, "jani not paid the right amount");
    }

    function testDistributeWithMint_ETH() public {
        // initial conditions
        assertEq(beekeeper.balance, 0, "init: not zero");
        assertEq(jani.balance, 0, "init: not zero");

        bearCave.setDisitrbuteWithMint(true);
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);

        // Will make a call to bearCave.mekHoneyCombWithETH(bearId).
        bytes memory request = abi.encodeWithSelector(BearCave.mekHoneyCombWithEth.selector, bearId);
        address(bearCave).functionCallWithValue(request, MINT_PRICE_ETH);

        uint256 beekeeperExpected = MINT_PRICE_ETH.mulWadUp(honeycombShare);

        assertEq(beekeeper.balance, beekeeperExpected, "beekeper not paid the right amount");
        assertEq(jani.balance, MINT_PRICE_ETH - beekeeperExpected, "jani not paid the right amount");
    }

    // ============= Claiming will be an integration test  ==================== //

    
    /**
     * Internal Helper methods
     */
    function _makeMultipleHoney(uint256 _bearId, uint256 _amount) internal {
        for (uint256 i = 0; i < _amount; i++) {
            paymentToken.mint(address(this), MINT_PRICE_ERC20);
            bearCave.mekHoneyCombWithERC20(_bearId);
        }
    }
}
