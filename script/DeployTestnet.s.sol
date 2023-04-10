// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.17;
// import "forge-std/Script.sol";

// import {HoneyComb} from "src/v1/HoneyComb.sol";
// import {GameRegistry} from "src/GameRegistry.sol";
// import {Gatekeeper} from "src/Gatekeeper.sol";
// import {BearCave} from "src/v1/BearCave.sol";
// import {IBearCave} from "src/v1/IBearCave.sol";
// import {MockERC1155} from "test/mocks/MockERC1155.sol";
// import {MockERC20} from "test/mocks/MockERC20.sol";

// contract DeployScript is Script {
//     // Goerli deps
//     address private VRF_COORDINATOR = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
//     bytes32 private VRF_KEYHASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

//     // Already deployed:
//     address private gameRegistry = 0x4208befD8f546282aB43A30085774513227B656C;
//     address private honeycomb = 0x1DeB9157508316A24BC0527444B142f563705BD0;
//     address private erc1155 = 0x21FDb00713C74147c2BB629De13531Ab51a94b8B;
//     address private paymentToken = 0x2F69c44dc3cb7C6508e49AD374BdfA332EB11416;

//     // Config
//     uint256 private honeycombShare = 2233 * 1e14;

//     bytes32 private keyhash = "";
//     uint64 private subId = 9;

//     function setUp() public {}

//     function run() public {
//         vm.startBroadcast();

//         // MockERC1155 erc1155 = new MockERC1155();
//         // MockERC20 paymentToken = new MockERC20("OHM", "OHM", 9);

//         // GameRegistry gameRegistry = new GameRegistry();

//         Gatekeeper gatekeeper = new Gatekeeper(address(gameRegistry));
//         // HoneyComb honeycomb = new HoneyComb(address(gameRegistry));

//         BearCave bearCave = new BearCave(
//             VRF_COORDINATOR,
//             address(gameRegistry),
//             address(honeycomb),
//             address(erc1155),
//             address(paymentToken),
//             address(gatekeeper),
//             honeycombShare
//         );

//         /**
//          * Setup
//          */

//         // Create mint Config
//         IBearCave.MintConfig memory mintConfig = IBearCave.MintConfig({
//             maxHoneycomb: 69,
//             maxClaimableHoneycomb: 4,
//             honeycombPrice_ERC20: 99 * 1e8, // 9.9 OHM
//             honeycombPrice_ETH: 99 * 1e6 * 1 gwei // 0.099 eth
//         });

//         bearCave.initialize(keyhash, subId, address(this), address(this), mintConfig);

//         // Register game with gameRegistry
//         // gameRegistry.registerGame(address(bearCave));

//         // Identify tokenID to hibernate
//         // Generate merkle roots..
//         // add gates w/ appropriate roots & stages to gatekeeper to gatekeeper.
//         // gameRegistry.startGame(address(bearCave));
//         // User hibernates bear:  calls start on gatekeeper.

//         vm.stopBroadcast();
//     }
// }
