// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {BearPouch} from "src/BearPouch.sol";
import {IBearPouch} from "src/interfaces/IBearPouch.sol";
import {Constants} from "src/Constants.sol";

import "./mocks/MockERC20.sol";

contract BearPouchTest is Test {
    using FixedPointMathLib for uint256;

    BearPouch private pouch;
    MockERC20 private mockToken = new MockERC20("Mock", "mock", 18);
    address private user1;
    address private user2;

    GameRegistry registry = new GameRegistry();

    function setUp() public {
        user1 = payable(makeAddr("user1"));
        user2 = payable(makeAddr("user2"));
        mockToken.mint(address(this), 2 * 10 ** mockToken.decimals()); // Have enough mockTokens
    }

    function testFail_invalidDistributionConfig() public {
        BearPouch.DistributionConfig memory config = IBearPouch.DistributionConfig(address(this), 1e17);
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](1);
        configs[0] = config;

        pouch = new BearPouch(address(registry), address(mockToken), configs);
    }

    function testUpdateDistribution() public {
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](2);
        configs[0] = IBearPouch.DistributionConfig(address(user1), 5 * 1e17);
        configs[1] = IBearPouch.DistributionConfig(address(user2), 5 * 1e17);

        pouch = new BearPouch(address(registry), address(mockToken), configs);

        for (uint256 i = 0; i < configs.length; i++) {
            (address r, uint256 s) = pouch.distributions(i);
            assertEq(r, configs[i].recipient);
            assertEq(s, configs[i].share);
        }

        BearPouch.DistributionConfig[] memory newConfigs = new IBearPouch.DistributionConfig[](2);
        newConfigs[0] = IBearPouch.DistributionConfig(address(user1), 8 * 1e17);
        newConfigs[1] = IBearPouch.DistributionConfig(address(user2), 2 * 1e17);

        pouch.updateDistributions(newConfigs); // Will fail if the values don't add up to 100%

        for (uint256 i = 0; i < newConfigs.length; i++) {
            (address r, uint256 s) = pouch.distributions(i);
            assertEq(r, newConfigs[i].recipient);
            assertEq(s, newConfigs[i].share);
        }
    }

    function testFail_wrongPermissions() public {
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](2);
        configs[0] = IBearPouch.DistributionConfig(address(user1), 5 * 1e17);
        configs[1] = IBearPouch.DistributionConfig(address(user2), 5 * 1e17);

        pouch = new BearPouch(address(registry), address(mockToken), configs);

        pouch.distribute(1e18);
    }

    function testFail_noAllowance() public {
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](2);
        configs[0] = IBearPouch.DistributionConfig(address(user1), 5 * 1e17);
        configs[1] = IBearPouch.DistributionConfig(address(user2), 5 * 1e17);

        pouch = new BearPouch(address(registry), address(mockToken), configs);

        registry.grantRole(Constants.GAME_INSTANCE, address(this)); // Only Game instance can call distribute
        pouch.distribute(1e18);
    }

    function testDistribution() public {
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](2);
        configs[0] = IBearPouch.DistributionConfig(address(user1), 5e17);
        configs[1] = IBearPouch.DistributionConfig(address(user2), 5e17);

        pouch = new BearPouch(address(registry), address(mockToken), configs);

        registry.grantRole(Constants.GAME_INSTANCE, address(this)); // Only Game instance can call distribute
        mockToken.approve(address(pouch), FixedPointMathLib.MAX_UINT256);

        pouch.distribute(1e18);

        assertEq(mockToken.balanceOf(user1), 5e17);
        assertEq(mockToken.balanceOf(user2), 5e17);
    }
}
