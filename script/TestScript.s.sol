// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {HoneyJar} from "src/HoneyJar.sol";

// import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
// import {CREATE3} from "solmate/utils/CREATE3.sol";
import {Create3} from "./Create3.sol";

// Calls honeyBox.addBundle

/// @notice this script is only meant to test do not use for production
contract TestScript is THJScriptBase {
    using stdJson for string;

    address private gameRegistry;
    address private deployer;

    HoneyJar private honeyJar;
    uint256 private honeyJarStartIndex;
    uint256 private honeyJarAmount;

    // CREATE2_FACTORY

    function setUp() public {
        gameRegistry = _readAddress("GAMEREGISTRY_ADDRESS");
        deployer = vm.parseAddress("0xF951bA8107D7BF63733188E64D7E07bD27b46Af7");
    }

    function run(string calldata env) public override {
        vm.startBroadcast();
        string memory json = _getConfig(env);

        honeyJarStartIndex = json.readUint(".honeyJar.startIndex");
        honeyJarAmount = json.readUint(".honeyJar.maxMintableForChain");

        bytes32 salt = keccak256(bytes("TheBearasLoveTheHoneyJar"));
        // bytes memory creationCode = type(HoneyJar).creationCode;
        // bytes memory constructorArgs = abi.encode(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);
        // bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);

        honeyJar = new HoneyJar{salt: salt}(deployer, gameRegistry, honeyJarStartIndex, honeyJarAmount);

        console.log("honeyJarAddy: ", address(honeyJar));
        vm.stopBroadcast();
    }
}
