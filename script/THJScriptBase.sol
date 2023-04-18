// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {GameRegistry} from "src/GameRegistry.sol";

contract THJScriptBase is Script {
    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function _readAddress(string memory envKey) internal view returns (address envAddress) {
        envAddress = vm.envAddress(envKey);
        require(envAddress != address(0), string.concat("Address incorrectly set for key - ", envKey));
        console.log(string.concat(envKey, ": "), envAddress);
    }

    function _readBytes32(string memory envKey) internal view returns (bytes32 envBytes32) {
        envBytes32 = vm.envBytes32(envKey);
        require(envBytes32 != bytes32(0), string.concat("Address incorrectly set for key - ", envKey));
        console.log(string.concat(envKey, ": "));
        console.logBytes32(envBytes32);
    }
}
