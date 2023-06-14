// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract GasTest is Test {
    uint256 BITMAP_INDEX = 12356;

    uint256 private chainId;
    uint256 private uintBitmap;
    mapping(uint256 => uint256) private mappingBitmap;

    function _getChainId() internal view returns (uint256) {
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
