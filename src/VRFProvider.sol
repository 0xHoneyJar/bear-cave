// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2} from "@chainlink/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {RrpRequesterV0} from "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title VRF Provider
/// @notice Custom VRF Provider that implements the Chainlink provider interface to delegate to another provider.
/// @dev Used on chains where there in no ChainLink VRF
/// @dev For chains with VRF, use the VRFCoordinator directly
/// @dev 1 provider for 1 recipient
/// @dev Future Optmizations: define as abstract contract that is implmented per provider
/// @dev Example: https://github.com/api3dao/qrng-example
contract VRFProvider is VRFCoordinatorV2Interface, RrpRequesterV0, Ownable {
    /// Errors
    error NotImplemented();
    error InvalidRecipient(address);

    /// Events
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);

    // These variables can also be declared as `constant`/`immutable`.
    // However, this would mean that they would not be updatable.
    // Since it is impossible to ensure that a particular Airnode will be
    // indefinitely available, you are recommended to always implement a way
    // to update these parameters.
    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    /// @notice represents "requestID" for chainlink
    uint256 public requestNumber;
    // TODO: Could be combined into a struct
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;
    mapping(bytes32 => uint256) public requestIdToRequestNumber;
    mapping(bytes32 => VRFConsumerBaseV2) public requestIdToRecipient;
    mapping(uint256 => bytes32) public requestNumToRequestId;
    mapping(address => bool) public isEnabled;

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _provider Airnode RRP contract address
    constructor(address _provider) RrpRequesterV0(_provider) {}

    /// @notice method to enable/disable recipients from requesting random numbers
    function setEnabled(address recipient_, bool isEnabled_) external onlyOwner {
        isEnabled[recipient_] = isEnabled_;
    }

    /// @notice (REQUIRED) Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(address _airnode, bytes32 _endpointIdUint256Array, address _sponsorWallet)
        external
        onlyOwner
    {
        airnode = _airnode;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    /// @notice Requests a `uint256[]`
    /// @dev This request will be fulfilled by the contract's sponsor wallet,
    /// which means spamming it may drain the sponsor wallet. Implement
    /// necessary requirements to prevent this, e.g., you can require the user
    /// to pitch in by sending some ETH to the sponsor wallet, you can have
    /// the user use their own sponsor wallet, you can rate-limit users.
    /// @param size Size of the requested array
    function _makeRequestUint256Array(uint256 size) internal returns (uint256 _requestNum) {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );

        expectingRequestWithIdToBeFulfilled[requestId] = true;
        requestIdToRequestNumber[requestId] = requestNumber;
        requestNumToRequestId[requestNumber] = requestId;
        requestIdToRecipient[requestId] = VRFConsumerBaseV2(msg.sender);
        _requestNum = requestNumber;
        requestNumber++;

        emit RequestedUint256Array(requestId, size);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256Array(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request ID not known");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 requestNum = requestIdToRequestNumber[requestId];
        VRFConsumerBaseV2 recipient = requestIdToRecipient[requestId];
        require(address(recipient) != address(0), "Recipient address zero");

        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));

        _sendRandomWords(recipient, requestNum, qrngUint256Array);

        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }

    /// @inheritdoc VRFCoordinatorV2Interface
    function requestRandomWords(
        bytes32, // keyhash
        uint64, // subId
        uint16, // minRequestConfirmations
        uint32, // callbackGasLimit
        uint32 numWords
    ) external returns (uint256 requestId) {
        if (!isEnabled[msg.sender]) {
            revert InvalidRecipient(msg.sender);
        }

        requestId = _makeRequestUint256Array(numWords);
    }

    /// @dev rawFulfillRandomWords valdiates that the reciving contract is being called by a valid VRF Coordinator
    /// @dev since this contract is acting like a VRFCoordinator this will work
    function _sendRandomWords(VRFConsumerBaseV2 recipient, uint256 requestId, uint256[] memory randomWords) internal {
        // TODO: massage random words into a chainLink format
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
