// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {HibernationDen} from "src/HibernationDen.sol";
// Calls honeyBox.addBundle

contract BundleTokens is THJScriptBase("gen6") {
    using stdJson for string;

    uint256 private SFT_ID = 4;
    uint256 private NFT_ID = 4;

    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {}

    // Notes: Only ETH -- Remember to update bundleId once done.
    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        HibernationDen hibernationDen = HibernationDen(payable(json.readAddress(".deployments.den")));

        uint256 mintChainId = json.readUint(".mintChainId");
        uint256[] memory checkpoints = json.readUintArray(".checkpoints");
        // address[] memory addresses = json.readAddressArray("$.bundleTokens[*].address");
        // uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        // bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        // Manual Entry
        // address addy = json.readAddress(".bundleTokens[*].address");
        // uint256 tokenId = json.readUint(".bundleTokens[*].id");
        // bool isERC1155 = json.readBool(".bundleTokens[*].isERC1155");
        address[] memory addresses = new address[](5);
        addresses[0] = 0x6C8fE8f2c7B9A5bAC8e0E31aFA05F53e18DA5714;
        addresses[1] = 0x6C8fE8f2c7B9A5bAC8e0E31aFA05F53e18DA5714;
        addresses[2] = 0x6C8fE8f2c7B9A5bAC8e0E31aFA05F53e18DA5714;
        addresses[3] = 0x6C8fE8f2c7B9A5bAC8e0E31aFA05F53e18DA5714;
        addresses[4] = 0x6C8fE8f2c7B9A5bAC8e0E31aFA05F53e18DA5714;

        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 10;
        tokenIds[1] = 11;
        tokenIds[2] = 12;
        tokenIds[3] = 13;
        tokenIds[4] = 14;

        bool[] memory isERC1155s = new bool[](5);
        isERC1155s[0] = false;
        isERC1155s[1] = false;
        isERC1155s[2] = false;
        isERC1155s[3] = false;
        isERC1155s[4] = false;

        vm.startBroadcast();
        // Identify tokenID to hibernate

        uint8 bundleId = hibernationDen.addBundle(mintChainId, checkpoints, addresses, tokenIds, isERC1155s);
        console.log("UPDATE CONFIG WITH BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
