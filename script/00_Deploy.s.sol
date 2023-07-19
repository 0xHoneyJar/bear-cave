// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {BeraPunk} from "src/BeraPunk/BeraPunk.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Den} from "src/BeraPunk/Den.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DeployScript is THJScriptBase("berapunk") {
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

        // Initializing StageTimes
        uint256[] memory stageTimes = new uint256[](1);
        stageTimes[0] = 0 hours;

        vm.startBroadcast();

        // Deploy gameRegistry and give gameAdmin permisisons
        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);
        gameRegistry.setStageTimes(stageTimes);

        // Deploy gatekeeper
        new Gatekeeper(address(gameRegistry));

        vm.stopBroadcast();
    }

    function deployToken(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = json.readAddress(".deployments.registry");
        address deployer = json.readAddress(".addresses.deployer");

        uint256 startIndex = json.readUint(".honeyJar.startIndex");
        uint256 tokenAmount = json.readUint(".honeyJar.maxMintableForChain");
        // string memory baseURI = json.readString(".honeyJar.baseURI");

        vm.startBroadcast();

        BeraPunk honeyJar = new BeraPunk(deployer, gameRegistry, startIndex, tokenAmount);
        // honeyJar.setBaseURI(baseURI);
        // TODO: SET BASE URI

        console.log("- Token: ", address(honeyJar));
        vm.stopBroadcast();
    }

    function deployHibernationDen(string calldata env) public {
        string memory json = _getConfig(env);

        address gameRegistry = json.readAddress(".deployments.registry");
        address gatekeeper = json.readAddress(".deployments.gatekeeper");
        address tokenAddress = json.readAddress(".deployments.token");

        address paymentToken = json.readAddress(".addresses.paymentToken");
        address vrfCoordinator = json.readAddress(".vrf.coordinator");
        uint64 subId = uint64(json.readUint(".vrf.subId"));
        address paymaster = json.readAddress(".addresses.paymaster");

        vm.startBroadcast();

        Den den = new Den(
            vrfCoordinator,
            gameRegistry,
            tokenAddress,
            paymentToken,
            gatekeeper,
            paymaster
        );

        console.log("-Den: ", address(den));
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
