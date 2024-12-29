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
        // gk.addGate(bundleId, 0xbb5c72e4fd398ac4b6647eb5746c12b695820935f228ecdd47375266a991f6d6, 214, 0); // IG
        // gk.addGate(bundleId, 0xf21cea41566e09e1abfb15622804f47066e3c148eeeb23a471670aad21456764, 1000, 0); // BG
        // gk.addGate(bundleId, 0x093dce164993a0878f91817bd0363c68adaf8eb6ea72fa275ad644d050fa3a09, 1378, 0); // HG
        // gk.addGate(bundleId, bytes32(0), 0, 0);
        // gk.addGate(bundleId, bytes32(0), 0, 0);
        // Set gate amount really high so the cap doesn't get hit
        // gk.addGate(bundleId, 0xf3db17cf1fdf936c25eeabe095b899bd6e3c7c68b520589198ec5f8bd107fdb9, 1990, 0);
        // gk.addGate(bundleId, 0xf98f0634125518724adb9059343a18f15063b3bde654a33f2d3e4b7a185b3adf, 6078, 0);
        gr.grantRole(Constants.GAME_INSTANCE, deployer);
        gk.startGatesForBundle(bundleId);
        gr.renounceRole(Constants.GAME_INSTANCE, deployer);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
