// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {HoneyBox} from "src/HoneyBox.sol";

// Calls honeyBox.addBundle

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase {
    using stdJson for string;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        address honeyBox = vm.envAddress("HONEYBOX_ADDRESS");

        // ReadConfig
        // address deployer = json.readAddress(".addresses.beekeeper");
        address gameAdmin = json.readAddress(".addresses.gameAdmin");

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        vm.startBroadcast(gameAdmin);

        // Approve all
        for (uint256 i = 0; i < addresses.length; i++) {
            if (isERC1155s[i]) {
                ERC1155(addresses[i]).setApprovalForAll(honeyBox, true);
                continue;
            }
            ERC721(addresses[i]).approve(honeyBox, tokenIds[i]);
        }

        HoneyBox(honeyBox).puffPuffPassOut(0);
    }
}
