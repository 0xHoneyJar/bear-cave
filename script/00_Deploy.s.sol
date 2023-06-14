// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HibernationDen} from "src/HibernationDen.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DeployScript is THJScriptBase("gen3") {
    using stdJson for string;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);
        console.log("chainId: ", json.readUint(".chainId"));
        console.log("NO DEFAULT BEHAVIOR", env);
        revert NotImplemented();
    }

    function deployHelpers(string calldata env) public {
        // Read Config
        string memory json = _getConfig(env);
        address gameAdmin = json.readAddress(".addresses.gameAdmin");
        address jani = json.readAddress(".addresses.jani");
        address beekeeper = json.readAddress(".addresses.beekeeper");

        vm.startBroadcast();

        // Deploy gameRegistry and give gameAdmin permisisons
        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);

        // Deploy gatekeeper
        new Gatekeeper(address(gameRegistry));

        vm.stopBroadcast();
    }

    function deployHoneyJar(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = json.readAddress(".deployments.registry");
        address deployer = json.readAddress(".addresses.deployer");

        uint256 honeyJarStartIndex = json.readUint(".honeyJar.startIndex");
        uint256 honeyJarAmount = json.readUint(".honeyJar.maxMintableForChain");

        vm.startBroadcast();

        bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarFurthermoreOogaBooga"));
        HoneyJar honeyJar = new HoneyJar{salt: salt}(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);

        console.log("- HoneyJarAddress: ", address(honeyJar));
        vm.stopBroadcast();
    }

    function deployHibernationDen(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = json.readAddress(".deployments.registry");
        address gatekeeper = json.readAddress(".deployments.gatekeeper");
        address honeyJar = json.readAddress(".deployments.honeyjar");

        address paymentToken = json.readAddress(".addresses.paymentToken");
        address vrfCoordinator = json.readAddress(".vrf.coordinator");
        address jani = json.readAddress(".addresses.jani");
        address beekeeper = json.readAddress(".addresses.beekeeper");

        uint256 revShare = json.readUint(".revShare");

        vm.startBroadcast();

        HibernationDen den = new HibernationDen(
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

    function deployHoneyJarPortal(string calldata env) public {
        string memory json = _getConfig(env);
        // Get Deployment Addresses
        address gameRegistry = json.readAddress(".deployments.registry");
        address hibernationDen = json.readAddress(".deployments.den");
        address honeyJar = json.readAddress(".deployments.honeyjar");

        // Get Configured Addresses
        address lzEndpoint = json.readAddress(".addresses.lzEndpoint");
        uint256 minGas = 200000;

        vm.startBroadcast();
        HoneyJarPortal portal = new HoneyJarPortal(minGas, lzEndpoint, honeyJar, hibernationDen, gameRegistry);
        vm.stopBroadcast();
    }
}
