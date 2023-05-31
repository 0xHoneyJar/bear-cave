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

    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        HibernationDen hibernationDen = HibernationDen(payable(json.readAddress(".deployments.hibernationDen")));

        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");
        uint256 chainId = json.readUint(".chainId");
        uint256[] memory checkpoints = json.readUintArray(".checkpoints");

        vm.startBroadcast();
        // Identify tokenID to hibernate
        uint8 bundleId = hibernationDen.addBundle(chainId, checkpoints, addresses, tokenIds, isERC1155s);
        console.log("BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
