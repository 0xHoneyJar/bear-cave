// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {HoneyBox} from "src/HoneyBox.sol";
// Calls honeyBox.addBundle

/// @notice this script is only meant to test
contract TestScript is THJScriptBase {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        for (uint256 i = 0; i < addresses.length; i++) {
            console.log(addresses[i]);
            console.log(tokenIds[i]);
            console.log(isERC1155s[i]);
        }
    }
}
