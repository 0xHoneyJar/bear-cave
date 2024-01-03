// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/VRFConsumerBaseV2.sol";
import {VRFProvider} from "src/VRFProvider.sol";
import {MockAirnodeRrp} from "./mocks/MockAirnodeRrp.sol";

/// @notice Mock contract for unit testing
contract MockAPI3Provider is MockAirnodeRrp {
    bytes4 private _functionId = VRFProvider.fulfillUint256Array.selector;
    uint256 randomSeed;

    constructor() {
        randomSeed = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.coinbase, block.prevrandao)));
    }

    function getRandom() public returns (uint256) {
        randomSeed = uint256(
            keccak256(
                abi.encodePacked(
                    randomSeed,
                    blockhash(block.number - ((randomSeed % 63) + 1)), //must choose at least 1 block before this one.
                    block.coinbase,
                    block.prevrandao
                )
            )
        );

        return randomSeed;
    }

    function simulateVRF(bytes32 requestId, address vrfProvider_)
        external
        returns (bool callSuccess, bytes memory callData)
    {
        /// Need to convert requestNum to requestId
        uint256[] memory randomNumbers = new uint256[](2);
        randomNumbers[0] = randomSeed;
        randomNumbers[1] = randomSeed / 2;

        bytes memory data = abi.encode(randomNumbers);

        // Call the adapter method to process the random numbers
        (callSuccess, callData) = vrfProvider_.call( // solhint-disable-line avoid-low-level-calls
        abi.encodeWithSelector(_functionId, requestId, data));

        // TODO: maybe make a call directly to the internal method fullfill()
        // Replace fulfill method.
    }
}

/// @notice Simulates the components of the hibernation den that use RNG
contract MockVRFRecipient is VRFConsumerBaseV2 {
    // Needed for testing, but doesn't matter what the user passes in
    struct VRFConfig {
        bytes32 keyHash;
        uint64 subId;
        uint16 minConfirmations;
        uint32 callbackGasLimit;
    }

    VRFConfig private _vrfConfig;
    VRFCoordinatorV2Interface internal immutable _vrfCoordinator;
    uint32 private numRandomWords = 2;

    // Store requestID to the values it recieved
    mapping(uint256 => uint256[]) public requestToNumbers;

    constructor(address _api3Provider) VRFConsumerBaseV2(_api3Provider) {
        _vrfCoordinator = VRFCoordinatorV2Interface(_api3Provider);
    }

    /// @notice simulates an a call to the VRF provider
    function getRandomNumber() external returns (uint256) {
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _vrfConfig.keyHash,
            _vrfConfig.subId,
            _vrfConfig.minConfirmations,
            _vrfConfig.callbackGasLimit,
            numRandomWords
        );

        return requestId;
    }

    /// @notice internal method following the Chainlink VRF interface.
    function fulfillRandomWords(uint256 _requestId, uint256[] memory randomWords) internal override {
        requestToNumbers[_requestId] = randomWords;
    }

    function getNumbersForId(uint256 requestId) external view returns (uint256[] memory) {
        return requestToNumbers[requestId];
    }
}

contract VRFProviderTest is Test {
    MockVRFRecipient public recipient;
    MockAPI3Provider public api3Provider;

    VRFProvider public provider; // The thing we're testing

    function setUp() public {
        // API3 Airnode
        api3Provider = new MockAPI3Provider();

        // VRF provider
        provider = new VRFProvider(address(api3Provider));

        //Instance of the Den
        recipient = new MockVRFRecipient(address(provider));

        // enable the recipient in the provider
        provider.setEnabled(address(recipient), true);

        // Point the provider to the right api3 node
        provider.setRequestParameters(address(api3Provider), "", address(this));
    }

    function testNotConfigured() public {
        provider.setEnabled(address(recipient), false);
        vm.expectRevert(abi.encodeWithSelector(VRFProvider.InvalidRecipient.selector, address(recipient)));
        recipient.getRandomNumber();
    }

    function testIncrementalRequestIds() public {
        uint256 requestId = recipient.getRandomNumber();
        assertEq(requestId, 0);

        requestId = recipient.getRandomNumber();
        assertEq(requestId, 1);
    }

    function testWorks() public {
        uint256 requestId = recipient.getRandomNumber();
        assertEq(requestId, 0);

        requestId = recipient.getRandomNumber();
        assertEq(requestId, 1);

        // Simulate VRF
        bytes32 reqIdBytes = provider.requestNumToRequestId(requestId);
        uint256 reqNum = provider.requestIdToRequestNumber(reqIdBytes);

        assertEq(requestId, reqNum);

        (bool isSuccess,) = api3Provider.simulateVRF(reqIdBytes, address(provider));
        assertTrue(isSuccess);

        uint256[] memory randomNumbers = recipient.getNumbersForId(requestId);
        assertEq(randomNumbers.length, 2);
        assertTrue(randomNumbers[0] != randomNumbers[1]);        
    }
}
