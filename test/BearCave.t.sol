// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "./mocks/MockERC1155.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVRFCoordinator.sol";
import "./utils/UserFactory.sol";
import "./utils/Random.sol";

import "src/BearCave.sol";
import {HoneyComb} from "src/HoneyComb.sol";

import {console2} from "forge-std/console2.sol";

contract BearCaveTest is Test, ERC1155TokenReceiver {
    using Random for uint256;

    uint256 private constant MAX_RANDOM = 69420782347;
    uint256 private constant MINT_PRICE = 9.9 * 1e9;
    uint32 private maxHoney = 4;
    uint16 private honeyShare = 2233; // in bps
    uint256 private bearId;
    MockERC1155 private erc1155;
    MockERC20 private paymentToken;

    address private beekeeper;
    address private jani;
    address private anotherUser;

    BearCave private bearCave;
    HoneyComb private honeycomb;

    //Chainlink setup
    MockVRFCoordinator private vrfCoordinator;
    uint96 private constant FUND_AMOUNT = 1 * 10 ** 18;

    // Initialize the test suite
    function setUp() public {
        // Deploy the ERC1155 token contract
        bearId = MAX_RANDOM.randomFromMax();
        console2.log("bearId", bearId);
        erc1155 = new MockERC1155();
        paymentToken = new MockERC20("OHM", "OHM", 9);
        paymentToken.mint(address(this), MINT_PRICE); // Only mint enough for 1 honeys

        beekeeper = makeAddr("beekeeper");
        jani = makeAddr("definitelyNotJani");
        anotherUser = makeAddr("ngmi");

        // Mint a bear to us
        erc1155.mint(address(this), bearId, 1, "");

        // Chainlink setup
        vrfCoordinator = new MockVRFCoordinator();
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        // deploy HoneyComb
        honeycomb = new HoneyComb();

        // Deploy the bearCave
        bearCave =
        new BearCave(address(vrfCoordinator), address(erc1155), address(paymentToken), address(honeycomb), MINT_PRICE, maxHoney, honeyShare);
        bearCave.setBeeKeeper(beekeeper);
        bearCave.setJani(jani);
        bearCave.setSubId(subId);

        vrfCoordinator.addConsumer(subId, address(bearCave));
    }

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

    function testFailMekHoney_wrongBearId() public {
        bearCave.mekHoneyComb(69);
    }

    function testFailMekHoney_noMoneys() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.burn(address(this), MINT_PRICE);

        assertEq(paymentToken.balanceOf(address(this)), 0, "how do you still have monies?");
        assertEq(paymentToken.allowance(address(this), address(bearCave)), 0, "bear cave can't take ur monies");
        bearCave.mekHoneyComb(bearId);
    }

    function testMekHoney() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);

        assertEq(honeycomb.balanceOf(address(this)), 0, "how do you already have honey?");
        paymentToken.approve(address(bearCave), MINT_PRICE);
        assertGe(paymentToken.balanceOf(address(this)), MINT_PRICE, "You dont have enough ohms");

        uint256 honeyId = bearCave.mekHoneyComb(bearId);
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
        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE);
        _makeMultipleHoney(bearId, maxHoney);

        // Gotta manually do this to simulate VRF working.
        _simulateVRF(bearId);

        assertEq(bearCave.getBear(bearId).specialHoneycombFound, true, "special honey is not found");
    }

    function testFailWakeBear_noBear() public {
        bearCave.wakeBear(69);
    }

    function testFailWakeBear_notEnoughHoney() public {
        // Same as the bear is sleeping
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE);
        bearCave.mekHoneyComb(bearId);

        bearCave.wakeBear(bearId);
    }

    function testFailWakeBear_wrongUser() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE);
        _makeMultipleHoney(bearId, maxHoney);

        _simulateVRF(bearId);

        vm.prank(anotherUser);
        bearCave.wakeBear(bearId);
    }

    function testFailWakeBear_allHoneyCombMoreTime() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE);
        _makeMultipleHoney(bearId, maxHoney);
        bearCave.wakeBear(bearId);
    }

    function testWakeBear() public {
        erc1155.setApprovalForAll(address(bearCave), true);
        bearCave.hibernateBear(bearId);
        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE);
        _makeMultipleHoney(bearId, maxHoney);

        _simulateVRF(bearId);

        bearCave.wakeBear(bearId);
        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    function testTwoSleepingBears() public {
        // TODO: can make this test more robust by validating the mekHoneyComb/findSpecial honey outputs.
        // uint256 secondBearId = MAX_RANDOM.randomFromMax(); // This shit isn't random.
        uint256 secondBearId = 69420;
        erc1155.setApprovalForAll(address(bearCave), true);
        erc1155.mint(address(this), secondBearId, 1, "");

        bearCave.hibernateBear(bearId);
        bearCave.hibernateBear(secondBearId);

        paymentToken.approve(address(bearCave), maxHoney * MINT_PRICE * 2);
        _makeMultipleHoney(bearId, maxHoney);
        _makeMultipleHoney(secondBearId, maxHoney);

        _simulateVRF(bearId);
        _simulateVRF(secondBearId);

        bearCave.wakeBear(bearId);
        bearCave.wakeBear(secondBearId);

        assertEq(erc1155.balanceOf(address(this), bearId), 1, "the bear didn't wake up");
    }

    function testWorks() public {
        assertTrue(true, "fuckin goteeem. r u even reading this?");
    }

    function testFailWithdrawFunds_noPerms() public {
        vm.prank(anotherUser);
        bearCave.withdrawFunds();
    }

    function testFailWithdrawFunds_noFunds() public {
        bearCave.withdrawFunds();
    }

    function testWithdrawFunds() public {
        // Setup: reset balances
        paymentToken.burn(address(bearCave), paymentToken.balanceOf(address(bearCave)));
        paymentToken.burn(address(this), paymentToken.balanceOf(address(this)));
        paymentToken.burn(beekeeper, paymentToken.balanceOf(beekeeper));

        uint256 ohmAmount = 10000;

        paymentToken.mint(address(bearCave), ohmAmount);
        assertEq(paymentToken.balanceOf(address(bearCave)), ohmAmount);

        vm.prank(beekeeper);
        uint256 amountLeft = bearCave.withdrawFunds();
        assertEq(amountLeft, 0);

        // Simple math since we're using 10000 as the ohm Amount in this test
        assertEq(paymentToken.balanceOf(beekeeper), honeyShare);
        assertEq(paymentToken.balanceOf(jani), ohmAmount - honeyShare);
    }

    /**
     * Internal Helper methods
     */
    function _makeMultipleHoney(uint256 _bearId, uint256 _amount) internal {
        for (uint256 i = 0; i < _amount; i++) {
            paymentToken.mint(address(this), MINT_PRICE);
            bearCave.mekHoneyComb(_bearId);
        }
    }
}
