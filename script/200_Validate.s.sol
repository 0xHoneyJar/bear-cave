// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";

import {HibernationDen} from "src/HibernationDen.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {HoneyJar} from "src/HoneyJar.sol";
import {Constants} from "src/Constants.sol";

import "./THJScriptBase.sol";
import "forge-std/Test.sol";

/// @notice this script is only meant to test do not use for production
contract ValidateScript is THJScriptBase("gen3"), Test {
    using stdJson for string;

    enum MessageTypes {
        SEND_NFT,
        START_GAME,
        SET_FERMENTED_JARS
    }

    function setUp() public {}

    function run(string calldata env) public override {
        // TODO:
        // validate VRF consumer.
        // Validate minDstGas

        // vm.startBroadcast();
        // vm.stopBroadcast();
    }

    function validate(string calldata l1, string calldata l2) public {
        string memory l1json = _getConfig(l1);
        string memory l2json = _getConfig(l2);

        uint256 l1ChainId = l1json.readUint(".chainId");
        uint256 l2ChainId = l2json.readUint(".chainId");

        ILayerZeroEndpoint lz_l1 = ILayerZeroEndpoint(l1json.readAddress(".addresses.lzEndpoint"));
        VRFCoordinatorV2Interface vrf_l1 = VRFCoordinatorV2Interface(l1json.readAddress(".vrf.coordinator"));
        uint256 subId_l1 = l1json.readUint(".vrf.subId");

        ILayerZeroEndpoint lz_l2 = ILayerZeroEndpoint(l2json.readAddress(".addresses.lzEndpoint"));
        VRFCoordinatorV2Interface vrf_l2 = VRFCoordinatorV2Interface(l1json.readAddress(".vrf.coordinator"));
        uint256 subId_l2 = l2json.readUint(".vrf.subId");

        // L1 Contracts
        HibernationDen den_l1 = HibernationDen(payable(l1json.readAddress(".deployments.den")));
        HoneyJarPortal p_l1 = HoneyJarPortal(payable(l1json.readAddress(".deployments.portal")));
        GameRegistry gr_l1 = GameRegistry(l1json.readAddress(".deployments.registry"));
        Gatekeeper gk_l1 = Gatekeeper(l1json.readAddress(".deployments.gatekeeper"));
        HoneyJar jar_l1 = HoneyJar(l1json.readAddress(".deployments.registry"));

        // L2 Contracts
        HibernationDen den_l2 = HibernationDen(payable(l2json.readAddress(".deployments.den")));
        HoneyJarPortal p_l2 = HoneyJarPortal(payable(l2json.readAddress(".deployments.portal")));
        GameRegistry gr_l2 = GameRegistry(l2json.readAddress(".deployments.registry"));
        Gatekeeper gk_l2 = Gatekeeper(l2json.readAddress(".deployments.gatekeeper"));
        HoneyJar jar_l2 = HoneyJar(l2json.readAddress(".deployments.registry"));

        uint8 bundleId = uint8(l1json.readUint(".bundleId"));
        address[] memory addresses = l1json.readAddressArray(".bundleTokens[*].address");

        ////////////////////////////////////////
        ///////////////  L1 Checks /////////////
        ////////////////////////////////////////
        uint256 forkId = vm.createFork(l1ChainId);
        HibernationDen.SlumberParty memory party = den_l1.getSlumberParty(bundleId);

        // Check that the party has the correct number of sleepoors
        assert(party.sleepoors.length == addresses.length, "invalid sleepoors");
        // Check that the trustedRemote on the portal is the same as the portal on L2
        uint256 mintChainId = l1json.readUint(".mintChainId");
        assert(party.mintChainId == mintChainId, "MintChainID does not match");
        uint16 lzChainId = p_l1.lzChainId(mintChainId);
        address portalL2 = p_l1.getTrustedRemoteAddress(lzChainId);
        assert(portalL2 == address(p_l2), "invalid trusted remote address");

        uint256 minGas = p_l1.minDstGasLookup(lzChainId, MessageTypes.START_GAME);
        assert(minGas > 400000, "MinGas for startGame too low");

        ////////////////////////////////////////
        ///////////////  L2 Checks /////////////
        ////////////////////////////////////////
        uint256 l2ForkId = vm.createFork(l2ChainId);
        // check that bundleId is an empty party
        party = den_l2.getSlumberParty(bundleId);
        assert(party.sleepoors.length == 0, "bundleId already exists on chain");
        Gatekeeper.Gate[] memory gates = gk_l2.tokenToGates(bundleId);
        assert(gates.length > 0, "no gates set for bundleId");

        lzChainId = p_l2.lzChainId(l2ForkId);
        portalL2 = p_l2.getTrustedRemoteAddress(lzChainId);
        assert(portalL2 == address(p_l1), "trusted remote address is not L1 portal");

        minGas = p_l2.minDstGasLookup(lzChainId, MessageTypes.SET_FERMENTED_JARS);
        assert(minGas > 400000, "MinGas for SET_FERMENTED_JARS too low");

        Gatekeeper.Gate memory gate;
        for (uint256 i = 0; i < gates.length; i++) {
            gate = gates[i];
            assert(gate.enabled == true, "gate not enabled");
        }
        // Validate vrf consumer is set
    }
}
