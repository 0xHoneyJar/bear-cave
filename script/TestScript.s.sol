// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";

import {HibernationDen} from "src/HibernationDen.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {HoneyJar} from "src/HoneyJar.sol";

import "./THJScriptBase.sol";

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase("gen3") {
    using stdJson for string;

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // startGame(json);
        checkDenJars(json);
        // fixFermentation(json);
        // sendFermented(json);
    }

    function sendFermented(string memory json) internal {
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        ILayerZeroEndpoint lz = ILayerZeroEndpoint(json.readAddress(".addressess.lzEndpoint"));
        HoneyJarPortal portal = HoneyJarPortal(json.readAddress(".deployments.portal"));

        uint8 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255
        uint256 assetChainId = json.readUint(".assetChainId");

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);

        uint256[] memory fermentedJarIds = new uint256[](party.fermentedJars.length);

        for (uint256 i = 0; i < fermentedJarIds.length; ++i) {
            fermentedJarIds[i] = party.fermentedJars[i].id;
        }

        bytes memory payload = abi.encode(
            HoneyJarPortal.MessageTypes.SET_FERMENTED_JARS,
            HoneyJarPortal.FermentedJarsPayload(bundleId, fermentedJarIds)
        );

        uint16 lzChainId = portal.lzChainId(assetChainId);
        (uint256 nativeFee,) = lz.estimateFees(lzChainId, address(den), payload, false, "");
        console.log("ETH REQUIRED: ", nativeFee);

        vm.startBroadcast();

        den.sendFermentedJars(0);

        // SRC address
        // lz.retryPayload(10121, abi.encodePacked(0x1399706d571ae4E915f32099995eE0ad9107AD96), payload);

        vm.stopBroadcast();
    }

    /// @notice this script is only meant to test do not use for production
    /// @notice mimicks the behavior of the portal to start a cross chain game. Run on L2
    function startGame(string memory json) internal {
        ILayerZeroEndpoint lz = ILayerZeroEndpoint(json.readAddress(".addressess.lzEndpoint"));
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        HoneyJarPortal portal = HoneyJarPortal(json.readAddress(".deployments.portal"));
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));
        address deployer = json.readAddress(".addresses.deployer");
        uint256 assetChainId = json.readUint(".assetChainId");

        bytes memory payload =
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000001A400000000000000000000000000000000000000000000000000000000000002B2000000000000000000000000000000000000000000000000000000000000058C0000000000000000000000000000000000000000000000000000000000000D0500000000000000000000000000000000000000000000000000000000000010680000000000000000000000000000000000000000000000000000000000001B390000000000000000000000000000000000000000000000000000000000002769";
        (, HoneyJarPortal.StartGamePayload memory startGamePayload) =
            abi.decode(payload, (HoneyJarPortal.MessageTypes, HoneyJarPortal.StartGamePayload));

        console.log(startGamePayload.bundleId, "bundleId");
        console.log(startGamePayload.numSleepers, "numSleepers");
        for (uint256 i = 0; i < startGamePayload.checkpoints.length; ++i) {
            console.log(startGamePayload.checkpoints[i]);
        }
        vm.startBroadcast();
        registry.grantRole(Constants.PORTAL, deployer);
        den.startGame(
            assetChainId, startGamePayload.bundleId, startGamePayload.numSleepers, startGamePayload.checkpoints
        );
        registry.renounceRole(Constants.PORTAL, deployer);
        vm.stopBroadcast();
    }

    function sendMijani(string memory json) internal {
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));
        HoneyJar hj = HoneyJar(json.readAddress(".deployments.honeyjar"));
        address deployer = json.readAddress(".addresses.deployer");
        address gameAdmin = json.readAddress(".addresses.gameAdmin");
        address mijaniSafe = 0x3FC232c07DCF2759AF9270f0a7D3856B9E8CCcBA;
        uint256 startId = 528;
        uint256 endId = 588;

        vm.startBroadcast();
        for (uint256 i = startId; i < endId; ++i) {
            hj.transferFrom(deployer, mijaniSafe, i);
        }
        vm.stopBroadcast();
    }

    function checkDenJars(string memory json) internal {
        uint8 bundleId = uint8(json.readUint(".bundleId"));
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);

        for (uint256 i = 0; i < party.fermentedJars.length; ++i) {
            console.log(party.fermentedJars[i].id, party.fermentedJars[i].isUsed);
        }
    }

    function fixFermentation(string memory json) internal {
        uint8 bundleId = uint8(json.readUint(".bundleId"));
        HibernationDen den = HibernationDen(payable(json.readAddress(".deployments.den")));
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));

        HibernationDen.SlumberParty memory party = den.getSlumberParty(bundleId);
        _printPartyInformation(party);

        // Additional fermentedJars obtained from `go run getRandom.go`
        uint256[] memory newFermentedJarsList = new uint256[](4);
        newFermentedJarsList[0] = party.fermentedJars[0].id;
        newFermentedJarsList[1] = party.fermentedJars[1].id;
        newFermentedJarsList[2] = 962;
        newFermentedJarsList[3] = 617;

        // uint256 pk = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(pk);
        // // Give the EOA portal permissions
        // den.setCrossChainFermentedJars(0, newFermentedJarsList);
        // vm.stopBroadcast();
        // party = den.getSlumberParty(0);
        // _printPartyInformation(party);
    }

    function _printPartyInformation(HibernationDen.SlumberParty memory party) internal view {
        console.log("bundleId", party.bundleId);
        console.log("numSleepers", party.sleepoors.length);
        console.log("checkpointIndex", party.checkpointIndex);
        console.log("fermentedJars", party.fermentedJars.length);
        console.log("sleepoors", party.sleepoors.length);
        console.log("checkpoints", party.checkpoints.length);

        for (uint256 i = 0; i < party.checkpoints.length; ++i) {
            console.log("checkpoint: ", i, party.checkpoints[i]);
        }

        for (uint256 i = 0; i < party.fermentedJars.length; ++i) {
            console.log("fermennted:", party.fermentedJars[i].id, party.fermentedJars[i].isUsed);
        }
    }
}
