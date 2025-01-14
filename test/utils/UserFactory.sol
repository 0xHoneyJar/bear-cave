// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17;

import {CommonBase} from "forge-std/Base.sol";

//common utilities for forge tests
contract UserFactory is CommonBase {
    bytes32 internal nextUser = keccak256(abi.encodePacked("users"));

    function next() public returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    //create users with 100 ether balance
    function create(uint256 userNum) public returns (address[] memory) {
        address[] memory usrs = new address[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address user = next();
            vm.deal(user, 100 ether);
            usrs[i] = user;
        }
        return usrs;
    }
}
