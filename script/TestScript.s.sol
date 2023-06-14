// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {HibernationDen} from "src/HibernationDen.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        // string memory json = _getConfig(env);
        GameRegistry registry = GameRegistry(0xc54692f4EBc5858c21F7bBea1BD1e2BcFe1090EE);

        // ReadConfig
        vm.startBroadcast();
        registry.grantRole(Constants.PORTAL, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        // registry.grantRole(Constants.BURNER, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        // registry.grantRole(Constants.MINTER, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        vm.stopBroadcast();
    }
}
