// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "forge-std/Script.sol";

import {HoneyComb} from "src/HoneyComb.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {BearCave} from "src/BearCave.sol";
import {IBearCave} from "src/IBearCave.sol";
import {Constants} from "src/Constants.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeployMainnet is Script {
    // Mainnet
    address private VRF_COORDINATOR = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909; //
    bytes32 private VRF_KEYHASH = 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92;
    uint64 private VRF_SUBID = 670;

    // Already deployed:
    address private gameRegistry = 0x21FDb00713C74147c2BB629De13531Ab51a94b8B;
    address private honeycomb = 0xCB0477d1Af5b8b05795D89D59F4667b59eAE9244;
    address private gatekeeper = 0x10b27a31AA4d7544F89898ccAf3Faf776F5671C4;
    address private erc1155 = 0x495f947276749Ce646f68AC8c248420045cb7b5e; // OpenSea
    address private paymentToken = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5; // OHm

    // Addresses

    address private jani = 0x25542Fd6204bbBe570E358B9ebeb391513980c34;
    address private beekeeper = 0x67EDbbF1531b28551f2075223D8a30a9AE457ECa;
    address private gameAdmin = 0xA4b1d4d0CcB3e73e5a4448FA07AC1c9526BE19Dd;

    // Config
    uint32 private maxHoneycomb = 16420;
    uint256 private honeycombShare = 2233 * 1e14; // In WAD (.2233)
    uint32 private maxClaimableHoneycomb = 6420;
    uint256 private honeycombPrice_ERC20 = 99 * 1e8; // 9.9 OHM
    uint256 private honeycombPrice_ETH = 99 * 1e6 * 1 gwei; // 0.099 eth

    function run() public {
        vm.startBroadcast();

        // // Game registry
        // GameRegistry gameRegistry = new GameRegistry();
        // gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        // gameRegistry.setJani(jani);
        // gameRegistry.setBeekeeper(beekeeper);

        // HoneyComb honeycomb = new HoneyComb(address(gameRegistry));
        // // honeycomb.transferRealOwnership(gameAdmin);

        // Gatekeeper gatekeeper = new Gatekeeper(address(gameRegistry));

        // BearCave
        BearCave bearCave = new BearCave(
            VRF_COORDINATOR,
            gameRegistry,
            honeycomb,
            erc1155,
            paymentToken,
            gatekeeper,
            honeycombShare
        );
        bearCave.setJani(jani);
        bearCave.setBeeKeeper(beekeeper);

        /**
         * Setup
         */

        // Create mint Config
        IBearCave.MintConfig memory mintConfig = IBearCave.MintConfig({
            maxHoneycomb: maxHoneycomb,
            maxClaimableHoneycomb: maxClaimableHoneycomb,
            honeycombPrice_ERC20: honeycombPrice_ERC20,
            honeycombPrice_ETH: honeycombPrice_ETH
        });

        bearCave.initialize(VRF_KEYHASH, VRF_SUBID, jani, beekeeper, mintConfig);
        GameRegistry(gameRegistry).registerGame(address(bearCave));

        // Register game with gameRegistry

        // Identify tokenID to hibernate
        // Generate merkle roots..
        // add gates w/ appropriate roots & stages to gatekeeper to gatekeeper.
        // gameRegistry.startGame(address(bearCave));
        // User hibernates bear:  calls start on gatekeeper.

        vm.stopBroadcast();
    }
}
