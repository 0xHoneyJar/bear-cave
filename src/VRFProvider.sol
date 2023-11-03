// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2} from "@chainlink/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";

/// @title VRF Provider
/// @notice Custom VRF Provider that implements the Chainlink provider interface to delegate to another provider.
/// @dev Used on chains where there in no ChainLink VRF
/// @dev For chains with VRF, use the VRFCoordinator directly
/// @dev 1 provider for 1 recipient
contract VRFProvider is VRFCoordinatorV2Interface {
    error NotImplemented();

    VRFConsumerBaseV2 public recipient;

    constructor(VRFConsumerBaseV2 _recipient) {
        recipient = _recipient;
    }

    /// @inheritdoc VRFCoordinatorV2Interface
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        // TODO
    }

    /// @dev rawFulfillRandomWords valdiates that the reciving contract is being called by a valid VRF Coordinator
    /// @dev since this contract is acting like a VRFCoordinator this will work
    function _sendRandomWords(uint256 requestId, uint256[] memory randomWords) internal {
        // TODO: message random words into a chainLink format
        recipient.rawFulfillRandomWords(requestId, randomWords);
    }

    // All the below are not implemented, they are not needed for the delegating of randomwords

    /// @notice Not Implemented
    function createSubscription() external returns (uint64 subId) {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function getRequestConfig() external view returns (uint16, uint32, bytes32[] memory) {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function getSubscription(uint64 subId)
        external
        view
        returns (uint96 balance, uint64 reqCount, address owner, address[] memory consumers)
    {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function addConsumer(uint64 subId, address consumer) external {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function removeConsumer(uint64 subId, address consumer) external {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function cancelSubscription(uint64 subId, address to) external {
        revert NotImplemented();
    }

    /// @notice Not Implemented
    function pendingRequestExists(uint64 subId) external view returns (bool) {
        revert NotImplemented();
    }
    /// @notice Not Implemented

    function acceptSubscriptionOwnerTransfer(uint64 subId) external {
        revert NotImplemented();
    }
}
