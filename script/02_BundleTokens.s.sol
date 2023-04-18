// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {HoneyBox} from "src/HoneyBox.sol";
// Calls honeyBox.addBundle

contract BundleTokens is THJScriptBase {
    uint256 private SFT_ID = 4;
    uint256 private NFT_ID = 4;

    HoneyBox private hb;
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {
        nft = ERC721(_readAddress("ERC721_ADDRESS"));
        sft = ERC1155(_readAddress("ERC1155_ADDRESS"));
        token = ERC20(_readAddress("ERC20_ADDRESS"));

        hb = HoneyBox(_readAddress("HONEYBOX_ADDRESS"));

        // TODO: read SFT_ID, NFT_ID from config
    }

    function run() public {
        vm.startBroadcast();

        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(nft);
        tokenAddresses[1] = address(sft);

        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;

        bool[] memory isERC1155s = new bool[](2);
        isERC1155s[0] = false;
        isERC1155s[1] = true;

        // Identify tokenID to hibernate
        uint8 bundleId = hb.addBundle(tokenAddresses, tokenIDs, isERC1155s);
        console.log("BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
