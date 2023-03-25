// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "forge-std/Script.sol";

import {GameRegistry} from "src/GameRegistry.sol";

contract StartGame is Script {
    address private bearCave = 0xb474f03c2c1e15596260CDa307f7827cdD3Fb749;
    address private gameRegistry = 0x21FDb00713C74147c2BB629De13531Ab51a94b8B;
    uint256 private bearId = 66075445032688988859229341194671037535804503065310441849644897953399848304641;

    function run() public {
        vm.startBroadcast();
        GameRegistry(gameRegistry).startGame(bearCave);
        vm.stopBroadcast();
    }
}
