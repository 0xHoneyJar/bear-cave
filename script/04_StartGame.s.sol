// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {GameRegistry} from "src/GameRegistry.sol";

contract StartGame is THJScriptBase("gen3") {
    using stdJson for string;

    GameRegistry private gr;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        address hibernationDen = json.readAddress(".deployments.hibernationDen");
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));

        vm.startBroadcast();

        gr.startGame(hibernationDen);

        vm.stopBroadcast();
    }
}
