// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {HibernationDen} from "src/HibernationDen.sol";

// Mints the required tokens to GameAdmin and starts the game
contract TestnetPuffPuff is THJScriptBase("gen2") {
    using stdJson for string;

    // External Addresses
    HibernationDen private honeyBox;
    MockERC20 private erc20;
    address private deployer;
    address private gameAdmin;
    uint8 private bundleId;

    function setUp() public {
        honeyBox = HibernationDen(payable(_readAddress("HONEYBOX_ADDRESS")));
    }

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // ReadConfig
        deployer = json.readAddress(".addresses.beekeeper");
        gameAdmin = json.readAddress(".addresses.gameAdmin");
        bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255

        erc20 = MockERC20(json.readAddress(".addresses.paymentToken"));
        address[] memory addresses = json.readAddressArray(".bundleTokens[*].address");
        uint256[] memory tokenIds = json.readUintArray(".bundleTokens[*].id");
        bool[] memory isERC1155s = json.readBoolArray(".bundleTokens[*].isERC1155");

        vm.startBroadcast();

        //Mint some payment tokens
        erc20.mint(deployer, 10 * 1e9);
        erc20.mint(gameAdmin, 10 * 1e9);

        // Approve all
        for (uint256 i = 0; i < addresses.length; i++) {
            if (isERC1155s[i]) {
                MockERC1155(addresses[i]).mint(deployer, tokenIds[i], 1, "");
                MockERC1155(addresses[i]).setApprovalForAll(address(honeyBox), true);
                continue;
            }
            MockERC721(addresses[i]).mint(deployer, tokenIds[i]);
            MockERC721(addresses[i]).approve(address(honeyBox), tokenIds[i]);
        }

        honeyBox.puffPuffPassOut(bundleId);

        vm.stopBroadcast();
    }
}
