// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract DenState {
    struct Jar {
        uint256 id;
        bool isUsed;
    }

    struct Party {
        Jar[] jars;
    }

    // BundleId -> Party mapping
    mapping(uint8 => Party) private parties;

    // Set Jars given a bundleId and array of uint256
    function setJars(uint8 bundleId, uint256[] memory jars) public {
        Party storage party = parties[bundleId];
        for (uint256 i = 0; i < jars.length; ++i) {
            party.jars.push(Jar(jars[i], false));
        }
    }
}

contract GasTest is Test {
    uint256 BITMAP_INDEX = 12356;

    uint256 private chainId;
    uint256 private uintBitmap;
    mapping(uint256 => uint256) private mappingBitmap;

    DenState private den = new DenState();

    function _getChainId() internal view returns (uint256) {
        return chainId;
    }

    function setUp() public {
        chainId = block.chainid;
    }

    // 142 gas
    function testReadingStorage() public view {
        chainId;
    }

    // 208 gas
    function testReadingBlock() public view {
        block.chainid;
    }

    // 164 gas
    function testFunctionReturn() public view {
        _getChainId();
    }

    // 120 Gas
    function testAssembly() public view {
        uint256 newChainId;
        assembly {
            newChainId := chainid()
        }
    }

    // [PASS] testVRFGas(uint256) (runs: 256, μ: 99794, ~: 46806)
    function testVRFGas(uint256 numJars) public {
        vm.assume(numJars > 0);
        vm.assume(numJars < 101);

        uint256[] memory jars = new uint256[](numJars);
        den.setJars(1, jars);
    }
}
