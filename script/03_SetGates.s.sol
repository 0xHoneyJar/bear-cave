// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {Gatekeeper} from "src/Gatekeeper.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Constants} from "src/Constants.sol";

contract SetGates is THJScriptBase("gen6") {
    using stdJson for string;

    function setUp() public {}

    // Note: Only Arbitrum
    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        Gatekeeper gk = Gatekeeper(json.readAddress(".deployments.gatekeeper"));
        GameRegistry gr = GameRegistry(json.readAddress(".deployments.registry"));
        address deployer = json.readAddress(".addresses.deployer");
        uint256 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255

        vm.startBroadcast();

        // TODO: stages should also be set before this.
        // TODO: could be moved into config
        //     function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(bundleId, 0x71e7e37b2cc22290f75d8f40a96a19e113c8d71ef407a5edbe69af18106a491a, 1505, 0);
        gk.addGate(bundleId, 0x98c543af0724e100f3c20e18e993b562b72e61fceeadec334fb5cd179b2cb0ee, 1222, 1);
        gk.addGate(bundleId, 0xf8da4b19e1c7688bc1116180cd3395434e186bb57d4930abf1a04b34200a7c36, 6697, 2);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
