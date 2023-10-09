// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {HibernationDen} from "src/HibernationDen.sol";
import {IHibernationDen} from "src/interfaces/IHibernationDen.sol";

// Sets up HibernationDen as a game
contract AddToParty is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        uint8 bundleId = uint8(json.readUint(".bundleId"));

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);
        assert(party.sleepoors.length > 0);

        // Add zero values for L2

        // If the transfer value is set to (true), the den will attempt to transfer the NFT into the contract
        /// function addToParty(uint8 bundleId_, SleepingNFT calldata sleeper, bool transfer)
        HibernationDen.SleepingNFT memory sleeper = IHibernationDen.SleepingNFT(address(0), 0, false);

        vm.startBroadcast();
        den.addToParty(bundleId, sleeper, false);
        vm.stopBroadcast();
    }
}
