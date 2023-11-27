// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {HibernationDen} from "src/HibernationDen.sol";

// Mints the required tokens to GameAdmin and starts the game
contract TestnetPuffPuff is THJScriptBase("gen3") {
    using stdJson for string;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // ReadConfig
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));

        address deployer = json.readAddress(".addresses.beekeeper");
        address gameAdmin = json.readAddress(".addresses.gameAdmin");

        MockERC20 erc20 = MockERC20(json.readAddress(".addresses.paymentToken"));
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
                MockERC1155(addresses[i]).setApprovalForAll(address(den), true);
                continue;
            }
            MockERC721(addresses[i]).mint(deployer, tokenIds[i]);
            MockERC721(addresses[i]).approve(address(den), tokenIds[i]);
        }
        vm.stopBroadcast();
    }

    function estimateAndPuff(string calldata env) public {
        string memory json = _getConfig(env);

        // ReadConfig
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        ILayerZeroEndpoint lz = ILayerZeroEndpoint(0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23);
        HoneyJarPortal portal = HoneyJarPortal(json.readAddress(".deployments.portal"));

        uint8 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255
        uint256 mintChainId = json.readUint(".mintChainId");
        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);
        bytes memory startGamePayload = abi.encode(
            HoneyJarPortal.MessageTypes.START_GAME,
            HoneyJarPortal.StartGamePayload(bundleId, party.maxMintsPerUser, party.sleepoors.length, party.checkpoints)
        );

        uint16 lzChainId = portal.lzChainId(mintChainId);
        (uint256 nativeFee,) = lz.estimateFees(lzChainId, address(den), startGamePayload, false, "");
        console.log("ETH REQUIRED: ", nativeFee);

        vm.startBroadcast();
        // portal.setAdapterParams(HoneyJarPortal.MessageTypes.START_GAME, 1, 520000); -- dont need this
        den.puffPuffPassOut{value: nativeFee * 2}(bundleId);
        // Execute on L2 if it fails
        // lz.retryPayload(10121, abi.encodePacked(0x1399706d571ae4E915f32099995eE0ad9107AD96), payload);
        // portal.sendStartGame{value: nativeFee * 2}(
        //     0xF951bA8107D7BF63733188E64D7E07bD27b46Af7, 421613, 1, 10, checkpoints
        // );

        vm.stopBroadcast();
    }
}
