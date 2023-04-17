// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {THJScriptBase} from "./THJScriptBase.sol";
import {GameRegistry} from "src/GameRegistry.sol";

contract StartGame is THJScriptBase {
    GameRegistry private gr;

    function run() public {
        vm.startBroadcast();

        address honeyBox = _readAddress("HONEYBOX_ADDRESS");
        gr = GameRegistry(_readAddress("GAMEREGISTRY_ADDRESS"));
        gr.startGame(honeyBox);

        vm.stopBroadcast();
    }
}
