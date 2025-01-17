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
        // address[] memory addresses2 = json.readAddressArray(".bundleTokens[*].address");
        // uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        // bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        // Manual Entry
        // address addy = json.readAddress(".bundleTokens[*].address");
        // uint256 tokenId = json.readUint(".bundleTokens[*].id");
        // bool isERC1155 = json.readBool(".bundleTokens[*].isERC1155");
        address[] memory addresses = new address[](18);
        addresses[0] = 0x39EB35a84752B4bd3459083834aF1267D276a54C; // 6312
        addresses[1] = 0x0B820623485dCFb1C40A70c55755160F6a42186D; // 6275
        addresses[2] = 0xa20CF9B0874c3E46b344DEAEEa9c2e0C3E1db37d; // 3903
        addresses[3] = 0x3f4DD25BA6Fb6441Bfd1a869Cbda6a511966456D; // 6812
        addresses[4] = 0x39EB35a84752B4bd3459083834aF1267D276a54C; // 6310
        addresses[5] = 0x0B820623485dCFb1C40A70c55755160F6a42186D; // 6274
        addresses[6] = 0xa20CF9B0874c3E46b344DEAEEa9c2e0C3E1db37d; // 3910
        addresses[7] = 0x3f4DD25BA6Fb6441Bfd1a869Cbda6a511966456D; // 6808
        addresses[8] = 0xa20CF9B0874c3E46b344DEAEEa9c2e0C3E1db37d; // 1382
        addresses[9] = 0x39EB35a84752B4bd3459083834aF1267D276a54C; // 6314
        addresses[10] = 0x0B820623485dCFb1C40A70c55755160F6a42186D; // 6276
        addresses[11] = 0xa20CF9B0874c3E46b344DEAEEa9c2e0C3E1db37d; // 1672
        addresses[12] = 0x39EB35a84752B4bd3459083834aF1267D276a54C; // 6313
        addresses[13] = 0x3f4DD25BA6Fb6441Bfd1a869Cbda6a511966456D; // 6810
        addresses[14] = 0x0B820623485dCFb1C40A70c55755160F6a42186D; // 6272
        addresses[15] = 0xa20CF9B0874c3E46b344DEAEEa9c2e0C3E1db37d; // 3905
        addresses[16] = 0x39EB35a84752B4bd3459083834aF1267D276a54C; // 6311
        addresses[17] = 0x3f4DD25BA6Fb6441Bfd1a869Cbda6a511966456D; // 6812

        uint256[] memory ids = new uint256[](18);
        ids[0] = 6312;
        ids[1] = 6275;
        ids[2] = 3903;
        ids[3] = 6812;
        ids[4] = 6310;
        ids[5] = 6274;
        ids[6] = 3910;
        ids[7] = 6808;
        ids[8] = 1382;
        ids[9] = 6314;
        ids[10] = 6276;
        ids[11] = 1672;
        ids[12] = 6313;
        ids[13] = 6810;
        ids[14] = 6272;
        ids[15] = 3905;
        ids[16] = 6311;
        ids[17] = 6812;

        bool[] memory isERC1155s = new bool[](18);
        isERC1155s[0] = false;
        isERC1155s[1] = false;
        isERC1155s[2] = false;
        isERC1155s[3] = false;
        isERC1155s[4] = false;
        isERC1155s[5] = false;
        isERC1155s[6] = false;
        isERC1155s[7] = false;
        isERC1155s[8] = false;
        isERC1155s[9] = false;
        isERC1155s[10] = false;
        isERC1155s[11] = false;
        isERC1155s[12] = false;
        isERC1155s[13] = false;
        isERC1155s[14] = false;
        isERC1155s[15] = false;
        isERC1155s[16] = false;
        isERC1155s[17] = false;

        vm.startBroadcast();
        // Identify tokenID to hibernate

        uint8 bundleId = hibernationDen.addBundle(mintChainId, checkpoints, addresses, ids, isERC1155s);
        console.log("UPDATE CONFIG WITH BundleID: ", bundleId);

        vm.stopBroadcast();
    }
}
