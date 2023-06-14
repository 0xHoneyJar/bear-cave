// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;

// import {ILayerZeroEndpoint} from "@layerzero/interfaces/ILayerZeroEndpoint.sol";

// import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";

// import {HibernationDen} from "src/HibernationDen.sol";
// import {GameRegistry} from "src/GameRegistry.sol";
// import {Gatekeeper} from "src/Gatekeeper.sol";
// import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
// import {HoneyJar} from "src/HoneyJar.sol";
// import {Constants} from "src/Constants.sol";

// import {THJScriptBase} from "./THJScriptBase.sol";
// import "forge-std/Test.sol";

// /// @notice this script is only meant to test do not use for production
// contract ValidateScript is THJScriptBase("gen3"), Test {
//     using stdJson for string;

//     Vm internal unsafeVM;
//     string private RPC_GOERLI;
//     string private RPC_ARB_GOERLI;

//     enum MessageTypes {
//         SEND_NFT,
//         START_GAME,
//         SET_FERMENTED_JARS
//     }

//     function setUp() public {
//         unsafeVM = Vm(VM_ADDRESS); // Use the vm from Test
//         RPC_GOERLI = vm.envString("GOERLI_URL");
//         RPC_ARB_GOERLI = vm.envString("ARB_GOERLI_URL");
//     }

//     function run(string calldata env) public override {}

//     function validate(string calldata l1, string calldata l2) public {
//         string memory l1json = _getConfig(l1);
//         string memory l2json = _getConfig(l2);

//         uint256 l1ChainId = l1json.readUint(".chainId");
//         uint256 l2ChainId = l2json.readUint(".chainId");

//         ILayerZeroEndpoint lz_l1 = ILayerZeroEndpoint(l1json.readAddress(".addresses.lzEndpoint"));
//         VRFCoordinatorV2Interface vrf_l1 = VRFCoordinatorV2Interface(l1json.readAddress(".vrf.coordinator"));
//         uint256 subId_l1 = l1json.readUint(".vrf.subId");

//         ILayerZeroEndpoint lz_l2 = ILayerZeroEndpoint(l2json.readAddress(".addresses.lzEndpoint"));
//         VRFCoordinatorV2Interface vrf_l2 = VRFCoordinatorV2Interface(l1json.readAddress(".vrf.coordinator"));
//         uint256 subId_l2 = l2json.readUint(".vrf.subId");

//         // L1 Contracts
//         HibernationDen den_l1 = HibernationDen(payable(l1json.readAddress(".deployments.den")));
//         HoneyJarPortal p_l1 = HoneyJarPortal(payable(l1json.readAddress(".deployments.portal")));
//         GameRegistry gr_l1 = GameRegistry(l1json.readAddress(".deployments.registry"));
//         Gatekeeper gk_l1 = Gatekeeper(l1json.readAddress(".deployments.gatekeeper"));
//         HoneyJar jar_l1 = HoneyJar(l1json.readAddress(".deployments.registry"));

//         // L2 Contracts
//         HibernationDen den_l2 = HibernationDen(payable(l2json.readAddress(".deployments.den")));
//         HoneyJarPortal p_l2 = HoneyJarPortal(payable(l2json.readAddress(".deployments.portal")));
//         GameRegistry gr_l2 = GameRegistry(l2json.readAddress(".deployments.registry"));
//         Gatekeeper gk_l2 = Gatekeeper(l2json.readAddress(".deployments.gatekeeper"));
//         HoneyJar jar_l2 = HoneyJar(l2json.readAddress(".deployments.registry"));

//         uint8 bundleId = uint8(l1json.readUint(".bundleId"));
//         address[] memory addresses = l1json.readAddressArray(".bundleTokens[*].address");

//         ////////////////////////////////////////
//         ///////////////  L1 Checks /////////////
//         ////////////////////////////////////////
//         uint256 forkId = unsafeVM.createFork(RPC_GOERLI);
//         HibernationDen.SlumberParty memory party = den_l1.getSlumberParty(bundleId);

//         // Check that the party has the correct number of sleepoors
//         assertEq(party.sleepoors.length, addresses.length, "invalid sleepoors");
//         // Check that the trustedRemote on the portal is the same as the portal on L2
//         uint256 mintChainId = l1json.readUint(".mintChainId");
//         assertEq(party.mintChainId, mintChainId, "MintChainID does not match");
//         uint16 lzChainId = p_l1.lzChainId(mintChainId);
//         bytes memory data = p_l1.getTrustedRemoteAddress(lzChainId);
//         address portalL2;
//         assembly {
//             portalL2 := mload(add(data, 20))
//         }
//         assertEq(portalL2, address(p_l2), "invalid trusted remote address");

//         uint256 minGas = p_l1.minDstGasLookup(lzChainId, uint16(MessageTypes.START_GAME));
//         assertGe(minGas, 400000, "MinGas for startGame too low");

//         ////////////////////////////////////////
//         ///////////////  L2 Checks /////////////
//         ////////////////////////////////////////
//         uint256 l2ForkId = unsafeVM.createFork(RPC_ARB_GOERLI);
//         // check that bundleId is an empty party
//         party = den_l2.getSlumberParty(bundleId);
//         // Checking the first gate
//         assertEq(party.sleepoors.length, 0, "bundleId already exists on chain");
//         (bool enabled,,,, bytes32 gateRoot,) = gk_l2.tokenToGates(bundleId, 0);

//         assertTrue(gateRoot != bytes32(0), "gateroot isn't set 0");
//         assertTrue(enabled, "gate not enabled");

//         lzChainId = p_l2.lzChainId(l2ForkId);
//         data = p_l2.getTrustedRemoteAddress(lzChainId);
//         assembly {
//             portalL2 := mload(add(data, 20))
//         }
//         assertEq(portalL2, address(p_l1), "trusted remote address is not L1 portal");

//         minGas = p_l2.minDstGasLookup(lzChainId, uint16(MessageTypes.SET_FERMENTED_JARS));
//         assertGe(minGas, 400000, "MinGas for SET_FERMENTED_JARS too low");

//         // Validate vrf consumer is set
//         // Validate minDstGas
//     }
// }
