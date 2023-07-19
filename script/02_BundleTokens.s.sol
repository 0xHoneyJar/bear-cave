// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {Den} from "src/BeraPunk/Den.sol";
// Calls honeyBox.addBundle

contract BundleTokens is THJScriptBase("berapunk") {
    using stdJson for string;

    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {}

    // Notes: Only ETH -- Remember to update bundleId once done.
    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        Den hibernationDen = Den(payable(json.readAddress(".deployments.den")));

        uint256 mintChainId = json.readUint(".mintChainId");
        uint256[] memory checkpoints = json.readUintArray(".checkpoints");
        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        vm.startBroadcast();
        // Identify tokenID to hibernate

        uint8 bundleId = hibernationDen.addBundle(mintChainId, checkpoints, addresses, tokenIds, isERC1155s);
        console.log("UPDATE CONFIG WITH BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
