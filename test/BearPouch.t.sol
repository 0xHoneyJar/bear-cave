// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {BearPouch} from "src/BearPouch.sol";
import {IBearPouch} from "src/interfaces/IBearPouch.sol";
import "./mocks/MockERC20.sol";

contract BearPouchTest is Test {
    BearPouch private pouch;
    MockERC20 private mockToken;

    GameRegistry registry = new GameRegistry();

    function testFail_invalidDistributionConfig() public {
        BearPouch.DistributionConfig memory config = IBearPouch.DistributionConfig(address(this), 1e17);
        BearPouch.DistributionConfig[] memory configs = new IBearPouch.DistributionConfig[](1);
        configs[0] = config;

        pouch = new BearPouch(address(registry), address(mockToken), configs);
    }
}
