// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

contract GasTest is Test {
    uint256 private chainId;

    function _getChainId() internal returns (uint256) {
        return chainId;
    }

    function setUp() public {
        chainId = block.chainid;
    }

    // 142 gas
    function testReadingStorage() public {
        chainId;
    }

    // 208 gas
    function testReadingBlock() public {
        block.chainid;
    }

    // 164 gas
    function testFunctionReturn() public {
        _getChainId();
    }

    // 120 Gas
    function testAssembly() public {
        uint256 newChainId;
        assembly {
            newChainId := chainid()
        }
    }
}
