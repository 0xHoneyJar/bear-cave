// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {THJScriptBase} from "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HoneyBox} from "src/HoneyBox.sol";
import {Constants} from "src/Constants.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DeployScript is THJScriptBase {
    // Chainlink Config
    address private vrfCoordinator;

    // Dependencies
    ERC20 private paymentToken;

    // Deployment vars
    Gatekeeper private gatekeeper;
    HoneyJar private honeyJar;
    HoneyBox private honeyBox;
    GameRegistry private gameRegistry;

    // Config
    // TODO: read from config/env
    uint256 private honeyJarShare = 2233 * 1e14;
    uint256 private honeyJarStartIndex = 0;
    uint256 private honeyJarAmount = 69;

    // Users to grant permissions
    address private gameAdmin;
    address private jani;
    address private beekeeper;

    function setUp() public {
        // Dependencies
        paymentToken = ERC20(_readAddress("ERC20_ADDRESS"));

        gameAdmin = _readAddress("GAMEADMIN_ADDRESS");
        jani = _readAddress("JANI_ADDRESS");
        beekeeper = _readAddress("BEEKEEPER_ADDRESS");

        // Read chainlink config
        vrfCoordinator = _readAddress("VRF_COORDINATOR");
    }

    function run() public {
        vm.startBroadcast();

        // Deploy gameRegistry and give gameAdmin permisisons
        gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        // Deploy gatekeeper
        gatekeeper = new Gatekeeper(address(gameRegistry));

        // Deploy HoneyJar with Create2
        honeyJar = new HoneyJar(address(gameRegistry), honeyJarStartIndex, honeyJarAmount);

        // Deploy HoneyBox
        honeyBox = new HoneyBox(
            address(vrfCoordinator),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            jani,
            beekeeper,
            honeyJarShare
        );

        vm.stopBroadcast();
    }
}
