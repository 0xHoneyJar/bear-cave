// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {HibernationDen} from "src/HibernationDen.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // ReadConfig
        GameRegistry gr = GameRegistry(json.readAddress(".deployments.registry"));
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        HoneyJarPortal portal = HoneyJarPortal(json.readAddress(".deployments.portal"));

        uint256[] memory checkpoints = new uint256[](3);
        checkpoints[0] = 2;
        checkpoints[1] = 10;
        checkpoints[2] = 20;

        vm.startBroadcast();
        // gr.grantRole(Constants.PORTAL, 0xF951bA8107D7BF63733188E64D7E07bD27b46Af7);

        den.startGame(5, 1, 10, checkpoints);
        vm.stopBroadcast();
    }
}
