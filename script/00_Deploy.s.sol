// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HibernationDen} from "src/HibernationDen.sol";
import {Constants} from "src/Constants.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DeployScript is THJScriptBase("gen3") {
    using stdJson for string;

    // Users to grant permissions
    address private deployer;

    function setUp() public {
        // Dependencies
        // If a deployment fails uncomment lines of existing deployments
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
    }

    function run(string calldata env) public override {
        // Existing deployments (if it fails)
        // gameRegistry = GameRegistry(_readAddress("GAMEREGISTRY_ADDRESS"));
        // honeyJar = HoneyJar(_readAddress("HONEYJAR_ADDRESS"));
        // honeyBox = HibernationDen(_readAddress("HONEYBOX_ADDRESS"));

        // Read Config
        string memory json = _getConfig(env);
        address gameAdmin = json.readAddress(".addresses.gameAdmin");
        address jani = json.readAddress(".addresses.jani");
        address beekeeper = json.readAddress(".addresses.beekeeper");

        vm.startBroadcast(deployer);

        // Deploy gameRegistry and give gameAdmin permisisons
        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        // Deploy gatekeeper
        new Gatekeeper(address(gameRegistry));

        // // Deploy HoneyJar with Create2
        // bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarOogaBooga"));
        // honeyJar = new HoneyJar{salt: salt}(deployer, address(gameRegistry), honeyJarStartIndex, honeyJarAmount);

        // Deploy HibernationDen
        // honeyBox = new HibernationDen(
        //     address(vrfCoordinator),
        //     address(gameRegistry),
        //     address(honeyJar),
        //     address(paymentToken),
        //     address(gatekeeper),
        //     jani,
        //     beekeeper,
        //     revShare
        // );

        vm.stopBroadcast();
    }

    function deployHoneyJar(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = _readAddress("GAMEREGISTRY_ADDRESS");

        uint256 honeyJarStartIndex = json.readUint(".honeyJar.startIndex");
        uint256 honeyJarAmount = json.readUint(".honeyJar.maxMintableForChain");

        vm.startBroadcast(deployer);

        bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarFurthermoreOogaBooga"));
        HoneyJar honeyJar = new HoneyJar{salt: salt}(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);

        console.log("- HoneyJarAddress: ", address(honeyJar));
        vm.stopBroadcast();
    }

    function deployHibernationDen(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = _readAddress("GAMEREGISTRY_ADDRESS");
        address gatekeeper = _readAddress("GATEKEEPER_ADDRESS");
        address honeyJar = _readAddress("HONEYJAR_ADDRESS");

        address paymentToken = json.readAddress(".addresses.paymentToken");
        address vrfCoordinator = json.readAddress(".vrf.coordinator");
        address jani = json.readAddress(".addresses.jani");
        address beekeeper = json.readAddress(".addresses.beekeeper");

        uint256 revShare = json.readUint(".revShare");

        vm.startBroadcast(deployer);

        HibernationDen den = new HibernationDen{salt:"anotherONe"}(
            vrfCoordinator,
            gameRegistry,
            honeyJar,
            paymentToken,
            gatekeeper,
            jani,
            beekeeper,
            revShare
        );

        console.log("-HibernationDenAddress: ", address(den));
        vm.stopBroadcast();
    }
}
