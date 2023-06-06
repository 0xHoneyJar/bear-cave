// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {HibernationDen} from "src/HibernationDen.sol";

// Sets up HibernationDen as a game
contract SendFermentedJars is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        uint8 bundleId = uint8(json.readUint(".bundleId"));

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);
        assert(party.sleepoors.length > 0);

        vm.startBroadcast();
        den.sendFermentedJars{value: 0.2 ether}(bundleId);
        vm.stopBroadcast();
    }
}
