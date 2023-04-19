// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {HoneyBox} from "src/HoneyBox.sol";

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// Sets up HoneyBox as a game
contract ConfigureGame is THJScriptBase {
    using stdJson for string;
    using SafeCastLib for uint256;

    // Chainlink Config
    address private vrfCoordinator;
    bytes32 private vrfKeyhash;
    uint64 private vrfSubId;

    // Dependencies
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    // Deployment vars

    HoneyBox private honeyBox;
    GameRegistry private gameRegistry;

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
        vrfSubId = json.readUint(".vrf.subId").safeCastTo64();
        vrfConfig = HoneyBox.VRFConfig(vrfKeyhash, vrfSubId, 3, 10000000);

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
