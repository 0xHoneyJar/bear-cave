// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {Gatekeeper} from "src/Gatekeeper.sol";

contract SetGates is THJScriptBase("gen3") {
    using stdJson for string;

    function setUp() public {}

    // Note: Only Arbitrum
    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        Gatekeeper gk = Gatekeeper(json.readAddress(".deployments.gatekeeper"));
        uint256 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255
        // TODO: When does general mint start?

        vm.startBroadcast();

        // TODO: could be moved into config
        //     function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(bundleId, 0x8caa438bc275ce2d266d67297054888df90c2cc2cd256bbe7a6f50ed605269c4, 214, 0); // IG
        gk.addGate(bundleId, 0xbb5c72e4fd398ac4b6647eb5746c12b695820935f228ecdd47375266a991f6d6, 1000, 0); // BG
        gk.addGate(bundleId, 0x093dce164993a0878f91817bd0363c68adaf8eb6ea72fa275ad644d050fa3a09, 1378, 0); // HG
        gk.addGate(bundleId, bytes32(0), 0, 0);
        gk.addGate(bundleId, bytes32(0), 0, 0);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
