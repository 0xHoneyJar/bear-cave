// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {HibernationDen} from "src/HibernationDen.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase {
    using stdJson for string;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        HoneyJar honeyJar = HoneyJar(vm.envAddress("HONEYJAR_ADDRESS"));
        // ReadConfig
        // address deployer = json.readAddress(".addresses.beekeeper");
        string memory baseURI = json.readString(".honeyJar.baseURI");

        // vm.startBroadCast(gameAdmin); // Simulate with GameAdmin
        vm.startBroadcast();

        honeyJar.setBaseURI(baseURI);
        honeyJar.setGenerated(true);
        vm.stopBroadcast();
    }
}
