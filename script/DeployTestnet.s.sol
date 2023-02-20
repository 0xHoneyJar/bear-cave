// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "forge-std/Script.sol";

import {HoneyComb} from "src/HoneyComb.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {BearCave} from "src/BearCave.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeployScript is Script {
    // Goerli deps
    address private VRF_COORDINATOR = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 private VRF_KEYHASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // Config
    uint256 private honeycombShare = 2233 * 1e14;

    function setUp() public {}

    function run() public {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast();

        MockERC1155 erc1155 = new MockERC1155();
        MockERC20 paymentToken = new MockERC20("OHM", "OHM", 9);

        GameRegistry gameRegistry = new GameRegistry();
        HoneyComb honeycomb = new HoneyComb(address(gameRegistry));

        BearCave bearCave = new BearCave(
            VRF_COORDINATOR,
            address(gameRegistry),
            address(honeycomb),
            address(erc1155),
            address(paymentToken),
            honeycombShare
        );

        // TODO: create mint config.
        // TODO: Create VRF Sub?
        // TODO: gatekeeper config

        vm.stopBroadcast();
    }
}
