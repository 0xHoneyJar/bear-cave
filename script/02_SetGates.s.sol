// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";

contract SetGates is THJScriptBase {
    string private envKey = "GATEKEEPER_ADDRESS";
    uint8 private BUNDLE_ID = 0;

    Gatekeeper private gk;

    function setUp() public {
        vm.startBroadcast();

        gk = Gatekeeper(_readAddress(envKey));
    }

    function run() public {
        //     function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(BUNDLE_ID, 0x79f399eaa629b0c00c3f4b23961988fccecac06a0d23d903b9ad2e7740147ace, 107, 0);
        gk.addGate(BUNDLE_ID, 0x99895320046b474b3bb8379d8a70071da548b780d593569b38a9edb913f6a386, 1823, 1);
        gk.addGate(BUNDLE_ID, 0x3548741ca16e843d3266bfbc4f0d1708498467dcdbd3b12766646234e9b08365, 0, 1);
        gk.addGate(BUNDLE_ID, 0xef4c955487aaab22a637870988751df04277a11882425987054dfe7f95e9ceed, 1420, 2);
        gk.addGate(BUNDLE_ID, 0x388f7680797434f1dc4f535643f01348c1136254545ec8aac9e09e47b5881d6d, 1650, 2);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
