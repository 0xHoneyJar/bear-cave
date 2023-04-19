// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HoneyBox} from "src/HoneyBox.sol";
import {Constants} from "src/Constants.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// Sets up HoneyBox as a game
contract ConfigureGame is THJScriptBase {
    using stdJson for string;

    // Chainlink Config
    address private vrfCoordinator;
    bytes32 private vrfKeyhash;

    // Dependencies
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    // Deployment vars

    HoneyBox private honeyBox;
    GameRegistry private gameRegistry;

    // Config
    bytes32 private keyhash;
    uint64 private subId = 9;

    HoneyBox.MintConfig private mintConfig;
    HoneyBox.VRFConfig private vrfConfig;

    function setUp() public {
        // Dependencies
        honeyBox = HoneyBox(_readAddress("HONEYBOX_ADDRESS"));
        gameRegistry = GameRegistry(_readAddress("GAMEREGISTRY_ADDRESS"));
    }

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        // Chainlink VRF Config
        vrfKeyhash = json.readBytes32(".vrf.keyhash");
        vrfConfig = HoneyBox.VRFConfig(vrfKeyhash, subId, 3, 10000000);

        // MintConfig
        bytes memory rawMintConfig = json.parseRaw(".mintConfig");
        mintConfig = abi.decode(rawMintConfig, (HoneyBox.MintConfig));

        vm.startBroadcast();

        honeyBox.initialize(vrfConfig, mintConfig);

        // Register game with gameRegistry
        gameRegistry.registerGame(address(honeyBox));

        vm.stopBroadcast();
    }
}
