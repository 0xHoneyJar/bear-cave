// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {HoneyBox} from "src/HoneyBox.sol";
// Calls honeyBox.addBundle

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase {
    using stdJson for string;

    address private honeyBox;

    HoneyBox.MintConfig mintConfig;

    function setUp() public {
        honeyBox = _readAddress("HONEYBOX_ADDRESS");
    }

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        bytes memory rawMintConfig = json.parseRaw(".mintConfig");
        mintConfig = abi.decode(rawMintConfig, (HoneyBox.MintConfig));
        console.log(mintConfig.maxHoneyJar);
        console.log(mintConfig.maxClaimableHoneyJar);
        console.log(mintConfig.honeyJarPrice_ERC20);
        console.log(mintConfig.honeyJarPrice_ETH);

        // Build out txns here.
        for (uint256 i = 0; i < addresses.length; i++) {
            if (isERC1155s[i]) {
                ERC1155(addresses[i]).setApprovalForAll(honeyBox, true);
                continue;
            }

            ERC721(addresses[i]).approve(honeyBox, tokenIds[i]);
            console.log(addresses[i]);
            console.log(tokenIds[i]);
            console.log(isERC1155s[i]);
        }
    }
}
