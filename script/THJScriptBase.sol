// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {GameRegistry} from "src/GameRegistry.sol";

contract THJScriptBase is Script {
    function _readAddress(string memory envKey) internal view returns (address) {
        address envAddress = vm.envAddress(envKey);
        require(envAddress != address(0), string.concat("Address incorrectly set for key - ", envKey));
        console.log(string.concat(envKey, ": "), envAddress);
        return envAddress;
    }
}
