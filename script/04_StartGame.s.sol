// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {GameRegistry} from "src/GameRegistry.sol";

contract StartGame is THJScriptBase {
    using stdJson for string;

    GameRegistry private gr;

    function run(string calldata env) public override {
        vm.startBroadcast();

        address honeyBox = _readAddress("HONEYBOX_ADDRESS");
        gr = GameRegistry(_readAddress("GAMEREGISTRY_ADDRESS"));
        gr.startGame(honeyBox);

        vm.stopBroadcast();
    }
}
