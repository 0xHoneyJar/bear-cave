// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

contract MockGameRegistry {
    bool internal returnVal;

    function hasRole(bytes32, address) public view returns (bool) {
        return returnVal;
    }

    function set(bool returnVal_) public {
        returnVal = returnVal_;
    }
}

contract HoneyJarTest is Test, ERC721TokenReceiver {
    MockGameRegistry private gameRegistry;
    address private anothaOne;
    HoneyJar private honeyJar;

    function setUp() public {
        anothaOne = makeAddr("anotherOne");

        gameRegistry = new MockGameRegistry();

        bytes32 salt = keccak256(bytes("BeraChainDoesNotExist"));
        bytes memory creationCode = type(HoneyJar).creationCode;
        bytes memory constructorArgs = abi.encode(address(this), address(gameRegistry), 0, 2);
        address honeyJarAddress = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorArgs));
        honeyJar = HoneyJar(honeyJarAddress);
    }

    function testOwnership() public {
        honeyJar.setGenerated(true);
        assertEq(honeyJar.owner(), address(this));
    }

    function testFailOwnership() public {
        vm.startPrank(anothaOne);
        honeyJar.setGenerated(true);
    }

    function testMint() public {
        gameRegistry.set(true);
        honeyJar.mintOne(address(this));
        assertEq(honeyJar.balanceOf(address(this)), 1);
    }

    function testFailMint_noPerms() public {
        honeyJar.mintTokenId(address(this), 1);
    }

    function testFailMintOneOverBounds() public {
        gameRegistry.set(true);
        honeyJar.mintOne(address(this));
        honeyJar.mintOne(address(this));
        honeyJar.mintOne(address(this));
    }

    function testMintOverBounds() public {
        gameRegistry.set(true);
        honeyJar.mintTokenId(address(this), 70);
    }
}
