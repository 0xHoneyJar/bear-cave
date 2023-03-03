// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "forge-std/Script.sol";

import {HoneyComb} from "src/HoneyComb.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {BearCave} from "src/BearCave.sol";
import {IBearCave} from "src/IBearCave.sol";
import {Constants} from "src/GameLib.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeployMainnet is Script {
    // Mainnet
    address private VRF_COORDINATOR = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909; //
    bytes32 private VRF_KEYHASH = 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92;
    uint64 private VRF_SUBID = 670;

    // Already deployed:
    // address private gameRegistry = 0x4208befD8f546282aB43A30085774513227B656C;
    // address private honeycomb = 0x1DeB9157508316A24BC0527444B142f563705BD0;
    address private erc1155 = 0x495f947276749Ce646f68AC8c248420045cb7b5e; // OpenSea
    address private paymentToken = 0x495f947276749Ce646f68AC8c248420045cb7b5e; // OHm

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

        // Game registry
        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        HoneyComb honeycomb = new HoneyComb(address(gameRegistry));
        // TODO: honeycomb.transferRealOwnership(gameAdmin);

        Gatekeeper gatekeeper = new Gatekeeper(address(gameRegistry));

        // BearCave
        BearCave bearCave = new BearCave(
            VRF_COORDINATOR,
            address(gameRegistry),
            address(honeycomb),
            address(erc1155),
            address(paymentToken),
            address(gatekeeper),
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

        bearCave.initialize(VRF_KEYHASH, VRF_SUBID, mintConfig);
        gameRegistry.registerGame(address(bearCave));

        // Register game with gameRegistry

        // Identify tokenID to hibernate
        // Generate merkle roots..
        // TODO:
        // add gates w/ appropriate roots & stages to gatekeeper to gatekeeper.
        // gameRegistry.startGame(address(bearCave));
        // User hibernates bear:  calls start on gatekeeper.

        vm.stopBroadcast();
    }
}
