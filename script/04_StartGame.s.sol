// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {HibernationDen} from "src/HibernationDen.sol";

contract StartGame is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        address payable den = payable(json.readAddress(".deployments.den"));
        address portal = json.readAddress(".deployments.portal");
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));

        vm.startBroadcast();

        registry.startGame(den);
        HibernationDen(den).setPortal(portal);

        vm.stopBroadcast();
    }
}
