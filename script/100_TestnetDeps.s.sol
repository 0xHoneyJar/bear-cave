// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

// Deploys ERC721, ERC20, ERC1155 to Game_Admin
contract TestnetDeps is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        address gameAdmin = json.readAddress(".addresses.gameAdmin");

        vm.startBroadcast();

        MockERC1155 erc1155 = new MockERC1155();
        MockERC721 erc721 = new MockERC721("MOCK", "mNFT");

        // TestnetPuffPuff.sol will mint the erc721 and erc1155 based on config

        MockERC20 paymentToken = new MockERC20("OHM", "OHM", 9);
        paymentToken.mint(gameAdmin, 99 * 1e8 * 100);

        console.log("ERC721: ", address(erc721));
        console.log("ERC1155: ", address(erc1155));
        console.log("ERC20: ", address(paymentToken));

        vm.stopBroadcast();
    }
}
