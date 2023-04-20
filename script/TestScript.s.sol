// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {HoneyJar} from "src/HoneyJar.sol";

// Calls honeyBox.addBundle

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase {
    using stdJson for string;

    address private gameRegistry;
    address private deployer;

    function setUp() public {
        gameRegistry = _readAddress("GAMEREGISTRY_ADDRESS");
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
    }

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        uint256 honeyJarStartIndex = json.readUint(".honeyJar.startIndex");
        uint256 honeyJarAmount = json.readUint(".honeyJar.maxMintableForChain");

        vm.startBroadcast(deployer);
        // bytes memory creationCode = type(HoneyJar).creationCode;
        // bytes memory constructorArgs = abi.encode(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);
        // bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);

        bytes32 salt = keccak256(bytes("BerasLoveTheHoneyJarOogaBooga"));
        HoneyJar honeyJar = new HoneyJar{salt: salt}(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);

        console.log("honeyJarAddy: ", address(honeyJar));
        vm.stopBroadcast();
    }
}
