// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {HoneyBox} from "src/HoneyBox.sol";
// Calls honeyBox.addBundle

contract BundleTokens is THJScriptBase {
    using stdJson for string;

    uint256 private SFT_ID = 4;
    uint256 private NFT_ID = 4;

    HoneyBox private hb;
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {
        hb = HoneyBox(_readAddress("HONEYBOX_ADDRESS"));
    }

    function run(string calldata env) public {
        vm.startBroadcast();

        string memory fullJsonPath = _getConfigPath(env);
        string memory json = vm.readFile(fullJsonPath);

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        // Identify tokenID to hibernate
        uint8 bundleId = hb.addBundle(addresses, tokenIds, isERC1155s);
        console.log(5);
        console.log("BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
