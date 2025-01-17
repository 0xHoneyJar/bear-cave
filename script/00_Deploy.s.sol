// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HibernationDen} from "src/HibernationDen.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DeployScript is THJScriptBase("gen6") {
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

        // Initializing StageTimes
        uint256[] memory stageTimes = new uint256[](4);
        stageTimes[0] = 1 hours; // Gate 1
        stageTimes[1] = 25 hours; // Gate 2
        stageTimes[2] = 49 hours; // Gate 3
        stageTimes[3] = 51 hours; // Gate 4 (Public)

        vm.startBroadcast();

        // Deploy gameRegistry and give gameAdmin permissions
        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.grantRole(Constants.GAME_ADMIN, jani);
        gameRegistry.setJani(jani);
        gameRegistry.setBeekeeper(beekeeper);
        gameRegistry.setStageTimes(stageTimes);

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
        string memory baseURI = json.readString(".honeyJar.baseURI");

        vm.startBroadcast();

        bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarFurthermoreOogaBooga"));
        HoneyJar honeyJar = new HoneyJar{salt: salt}(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);
        honeyJar.setBaseURI(baseURI);

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
        uint64 subId = uint64(json.readUint(".vrf.subId"));
        address jani = json.readAddress(".addresses.jani");
        address beekeeper = json.readAddress(".addresses.beekeeper");

        uint256 revShare = json.readUint(".revShare");

        vm.startBroadcast();

        HibernationDen den = new HibernationDen(
            vrfCoordinator, gameRegistry, honeyJar, paymentToken, gatekeeper, jani, beekeeper, revShare
        );

        console.log("-HibernationDenAddress: ", address(den));
        // VRFCoordinatorV2Interface(vrfCoordinator).addConsumer(subId, address(den));
        console.log("---REMEMBER TO ADD DEN AS A VRF CONSUMER---");

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
