// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "forge-std/Script.sol";

import {Gatekeeper} from "src/Gatekeeper.sol";

contract SetGates is Script {
    address private gatekeeper = 0x10b27a31AA4d7544F89898ccAf3Faf776F5671C4;
    uint256 private bearId = 66075445032688988859229341194671037535804503065310441849644897953399848304641;

    function run() public {
        vm.startBroadcast();
        Gatekeeper gatekeeperInstance = Gatekeeper(gatekeeper);

        gatekeeperInstance.addGate(bearId, 0x6634ba781bc13377cfb2bd014862dd753df7b080d8bfddc9ed59e5b4ed966a16, 107, 0);
        gatekeeperInstance.addGate(bearId, 0x3bd1747adc06ad4a02e3eef59cde51b78aa1319c1e4aff7f88930be56c779c66, 1823, 0);
        gatekeeperInstance.addGate(bearId, 0x4234f797e4342f099b6fee4d7fd56d0e6b23d8700e6252f4a3b71fcb9c99f11d, 1420, 2);
        gatekeeperInstance.addGate(bearId, 0xf8216e27858bce2821c152437fd5dfaae5900227d288a6b668675e3ed2ca1e62, 1650, 2);

        vm.stopBroadcast();
    }
}
