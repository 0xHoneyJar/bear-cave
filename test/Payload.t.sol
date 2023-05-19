// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

contract Payload is Test {
    enum MessageType {
        FIRST_MESSAGE,
        SECOND_MESSAGE
    }

    struct MessageOne {
        string name;
        uint256 value;
        address caller;
    }

    struct MessageTwo {
        uint256[] numbers;
    }

    MessageOne private msg1;
    MessageTwo private msg2;

    function setUp() public {
        msg1 = MessageOne("testname", 123, address(this));

        msg2.numbers.push(1);
        msg2.numbers.push(2);
    }

    function testPayload() public {
        bytes memory encodedMsg1 = abi.encode(MessageType.FIRST_MESSAGE, msg1);
        bytes memory encodedMsg2 = abi.encode(MessageType.SECOND_MESSAGE, msg2);

        (MessageType msgType1) = abi.decode(encodedMsg1, (MessageType));
        assertEq(uint256(msgType1), uint256(MessageType.FIRST_MESSAGE));

        (, MessageOne memory decodedMsg1) = abi.decode(encodedMsg1, (MessageType, MessageOne));
        assertEq(decodedMsg1.caller, address(this));

        (MessageType msgType2) = abi.decode(encodedMsg2, (MessageType));
        assertEq(uint256(msgType2), uint256(MessageType.SECOND_MESSAGE));
        (, MessageTwo memory decodedMsg2) = abi.decode(encodedMsg2, (MessageType, MessageTwo));
        assertEq(decodedMsg2.numbers.length, 2);
        assertEq(decodedMsg2.numbers[0], 1);
        assertEq(decodedMsg2.numbers[1], 2);
    }
}
