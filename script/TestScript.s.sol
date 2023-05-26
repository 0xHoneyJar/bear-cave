// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {HibernationDen} from "src/HibernationDen.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase("gen2") {
    // using stdJson for string;

    function run(string calldata env) public override {
        // string memory json = _getConfig(env);

        // HoneyJar honeyJar = HoneyJar(vm.envAddress("HONEYJAR_ADDRESS"));
        // ReadConfig
        // address deployer = json.readAddress(".addresses.beekeeper");

        // vm.startBroadCast(gameAdmin); // Simulate with GameAdmin
        vm.startBroadcast();

        HibernationDen den = new HibernationDen(
            0x6D80646bEAdd07cE68cab36c27c626790bBcf17f,
            0x0B9a7a17D0EBc02EF1832ea040Cb629eCa83AD14,
            0x613a642C473D4DB6363Bd9c58c1ef101dDf40232,
            0x9Db2ea779Cd3F9F8aEB5E58EB1223a585a4D7D68,
            0x0B9a7a17D0EBc02EF1832ea040Cb629eCa83AD14,
            0xF951bA8107D7BF63733188E64D7E07bD27b46Af7,
            0xF951bA8107D7BF63733188E64D7E07bD27b46Af7,
            223300000000000000
        );
        vm.stopBroadcast();
    }
}
