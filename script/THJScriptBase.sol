// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {GameRegistry} from "src/GameRegistry.sol";

abstract contract THJScriptBase is Script {
    /// @notice must pass in an env name for the script to run
    /// @notice env the environment: mainnet, goerli, polygon, etc.
    function run(string calldata env) public virtual;

    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    /// @notice only is used to read the config path based on the environemtn.
    function _getConfigPath(string memory env) internal view returns (string memory) {
        string memory filename = string.concat(env, ".json");
        string memory jsonPath = string.concat("/script/config.", filename);
        string memory root = vm.projectRoot();
        console.log("Loading Config: ", jsonPath);
        return string.concat(root, jsonPath);
    }

    function _getConfig(string memory env) internal view returns (string memory) {
        string memory fullJsonPath = _getConfigPath(env);
        return vm.readFile(fullJsonPath);
    }

    function _readAddress(string memory envKey) internal view returns (address envAddress) {
        envAddress = vm.envAddress(envKey);
        require(envAddress != address(0), string.concat("Address incorrectly set for key - ", envKey));
        console.log(string.concat(envKey, ": "), envAddress);
    }

    function _readBytes32(string memory envKey) internal view returns (bytes32 envBytes32) {
        envBytes32 = vm.envBytes32(envKey);
        require(envBytes32 != bytes32(0), string.concat("Address incorrectly set for key - ", envKey));
        console.log(string.concat(envKey, ": "));
        console.logBytes32(envBytes32);
    }
}
