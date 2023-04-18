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
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

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
    address private deployer;

    function setUp() public {
        // Dependencies
        paymentToken = ERC20(_readAddress("ERC20_ADDRESS"));

        gameAdmin = _readAddress("GAMEADMIN_ADDRESS");
        jani = _readAddress("JANI_ADDRESS");
        beekeeper = _readAddress("BEEKEEPER_ADDRESS");

        // Read chainlink config
        vrfCoordinator = _readAddress("VRF_COORDINATOR");
        deployer = vm.parseAddress("0xF951bA8107D7BF63733188E64D7E07bD27b46Af7");
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
        bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarOogaBooga"));
        bytes memory creationCode = type(HoneyJar).creationCode;
        bytes memory constructorArgs = abi.encode(deployer, address(gameRegistry), honeyJarStartIndex, honeyJarAmount);
        address honeyJarAddress = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorArgs));
        honeyJar = HoneyJar(honeyJarAddress);

        // honeyJar = new HoneyJar(address(gameRegistry), honeyJarStartIndex, honeyJarAmount);

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
