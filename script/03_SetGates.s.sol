// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {Gatekeeper} from "src/Gatekeeper.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Constants} from "src/Constants.sol";

contract SetGates is THJScriptBase("berapunk") {
    using stdJson for string;

    function setUp() public {}

    // Note: Only Arbitrum
    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        Gatekeeper gk = Gatekeeper(json.readAddress(".deployments.gatekeeper"));
        GameRegistry gr = GameRegistry(json.readAddress(".deployments.registry"));
        address deployer = json.readAddress(".addresses.deployer");
        uint256 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255
        // TODO: When does general mint start?

        vm.startBroadcast();

        // TODO: could be moved into config
        // function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(bundleId, 0xab342ec24fbee210e0cc55908aea0c9ca5c91d4bc811dbf03ac994f6a84d60d1, 1068, 0); //
        gk.addGate(bundleId, 0x9e9fef934e11275b72de2f9ddef3a3ce939f73c61e01fe2cda11f6067d43df02, 0, 0);
        gk.addGate(bundleId, 0x4ce205a82e9ce0f7ee04897e4cb0a5884e4968259bf403435be4dd6f72dc37c9, 0, 0);
        // gk.addGate(bundleId, bytes32(0), 0, 0);
        // gk.addGate(bundleId, bytes32(0), 0, 0);
        // gk.addGate(bundleId, 0xd22a43979c4308f70aa99543f681021e18f28ff4410b078bbc1cc9097752eff4, 60, 0);
        // gr.grantRole(Constants.GAME_INSTANCE, deployer);
        // gk.startGatesForBundle(bundleId);
        // gr.renounceRole(Constants.GAME_INSTANCE, deployer);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
