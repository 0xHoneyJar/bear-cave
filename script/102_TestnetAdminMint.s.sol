// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {HibernationDen} from "src/HibernationDen.sol";

// Mints the required tokens to GameAdmin and starts the game
contract TestnetAdminMint is THJScriptBase("beradoge") {
    using stdJson for string;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // ReadConfig
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));

        address deployer = json.readAddress(".addresses.beekeeper");
        address gameAdmin = json.readAddress(".addresses.gameAdmin");

        vm.startBroadcast();

        den.adminMint(0, 233);

        vm.stopBroadcast();
    }
}
