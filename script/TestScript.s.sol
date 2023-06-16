// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";

import {HibernationDen} from "src/HibernationDen.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        // GameRegistry registry = GameRegistry(0xc54692f4EBc5858c21F7bBea1BD1e2BcFe1090EE);
        // MockERC20 paymentToken = MockERC20(0x9Db2ea779Cd3F9F8aEB5E58EB1223a585a4D7D68);

        // ReadConfig
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        ILayerZeroEndpoint lz = ILayerZeroEndpoint(json.readAddress(".addressess.lzEndpoint"));
        HoneyJarPortal portal = HoneyJarPortal(json.readAddress(".deployments.portal"));

        uint8 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255
        uint256 assetChainId = json.readUint(".assetChainId");

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);

        bytes memory startGamePayload = abi.encode(
            HoneyJarPortal.MessageTypes.SET_FERMENTED_JARS,
            HoneyJarPortal.FermentedJarsPayload(bundleId, party.fermentedJars);
        );

        uint16 lzChainId = portal.lzChainId(assetChainId);
        (uint256 nativeFee,) = lz.estimateFees(lzChainId, address(den), startGamePayload, false, "");
        console.log("ETH REQUIRED: ", nativeFee);

        // ReadConfig
        vm.startBroadcast();

        // Destination Address (src chain, src Address, payload);
        lz.retryPayload(10121, abi.encodePacked(0x1399706d571ae4E915f32099995eE0ad9107AD96), payload);

        // paymentToken.mint(0x79092A805f1cf9B0F5bE3c5A296De6e51c1DEd34, 1000 * 1e9)
        // registry.grantRole(Constants.PORTAL, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        // registry.grantRole(Constants.BURNER, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        // registry.grantRole(Constants.MINTER, 0x700d64fF07e672072850a9F581Ea9c43645B4502);
        vm.stopBroadcast();
    }
}
