// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {HoneyBox} from "src/HoneyBox.sol";
// Calls honeyBox.addBundle

contract TestScript is THJScriptBase {
    using stdJson for string;

    string private json;

    function _getFilePath(string memory filePath) private view returns (string memory) {
        string memory filename = string.concat(filePath, ".json");
        string memory jsonPath = string.concat("/script/config.", filename);
        string memory root = vm.projectRoot();
        console.log("Loading Config: ", jsonPath);
        return string.concat(root, jsonPath);
    }

    function _getBundleTokens() public view returns (HoneyBox.SleepingNFT[] memory) {
        bytes memory parsedBundleTokens = json.parseRaw(".bundleTokens");
        return abi.decode(parsedBundleTokens, (HoneyBox.SleepingNFT[]));
    }

    function run(string calldata env) public {
        string memory fullJsonPath = _getFilePath(env);
        json = vm.readFile(fullJsonPath);

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        HoneyBox.SleepingNFT[] memory sleepers = _getBundleTokens();
        for (uint256 i = 0; i < sleepers.length; i++) {
            console.log(addresses[i]);
            console.log(tokenIds[i]);
            console.log(isERC1155s[i]);
        }
    }
}
