// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {HibernationDen} from "src/HibernationDen.sol";
// Calls honeyBox.addBundle

contract BundleTokens is THJScriptBase("gen3") {
    using stdJson for string;

    uint256 private SFT_ID = 4;
    uint256 private NFT_ID = 4;

    HibernationDen private hb;
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {
        hb = HibernationDen(payable(_readAddress("HONEYBOX_ADDRESS")));
    }

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        vm.startBroadcast();

        uint256 CHAIN_ID = 0; // ETH
        uint256[] memory checkpoints; // TODO: put the real checkpoints here.

        // Identify tokenID to hibernate
        uint8 bundleId = hb.addBundle(CHAIN_ID, checkpoints, addresses, tokenIds, isERC1155s);
        console.log("BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
