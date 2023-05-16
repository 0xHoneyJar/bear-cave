// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {ONFT721Core} from "@layerzero/token/onft/ONFT721Core.sol";

import {CrossChainTHJ} from "src/CrossChainTHJ.sol";
import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Constants} from "src/Constants.sol";
import {IHoneyJar} from "src/IHoneyJar.sol";

interface IHoneyBox {
    function startGame(uint8 bundleId, CrossChainTHJ.CrossChainBundleConfig calldata config) external;
}

/// @title HoneyJarPortal
/// @notice Manages cross chain business logic and interactions with HoneyJar NFT
/// @dev Modeled off of @layerzero/token/onft/extension/ProxyONFT721.sol
/// @dev Is subject to change with v3 development
contract HoneyJarPortal is GameRegistryConsumer, CrossChainTHJ, ONFT721Core, IERC721Receiver {
    using ERC165Checker for address;

    uint16 public constant FUNCTTION_TYPE_START = 2;

    // Events
    event PortalSet(uint256 chainId, address portalAddress);
    event StartCrossChainGame(uint256 chainId, CrossChainBundleConfig bundleConfig);
    event MessageRecieved(bytes payload);

    // Errors
    error InvalidToken(address tokenAddress);
    error HoneyJarNotInPortal(uint256 tokenId);
    error OwnerNotCaller();
    error PortalDoesNotExist(uint256 destChainId);

    enum MessageTypes {
        SEND_NFT,
        START_GAME
    }

    // Dependencies
    IHoneyJar public immutable honeyJar;

    /// @notice mapping of chainId --> HoneyJar Portals
    mapping(uint256 => address) public otherPortals;
    mapping(uint256 => uint256) public dstChainIdToStartGame;

    constructor(uint256 _minGasToTransfer, address _lzEndpoint, address _honeyJar, address _gameRegistry)
        ONFT721Core(_minGasToTransfer, _lzEndpoint)
        GameRegistryConsumer(_gameRegistry)
    {
        if (!_honeyJar.supportsInterface(type(IERC721).interfaceId)) revert InvalidToken(_honeyJar);
        honeyJar = IHoneyJar(_honeyJar);
    }

    function setPortal(uint256 destChainId_, address portalAddress_) external onlyRole(Constants.GAME_ADMIN) {
        otherPortals[destChainId_] = portalAddress_;

        emit PortalSet(destChainId_, portalAddress_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function setDstChainIdToStartGame(uint16 dstChainId_, uint256 dstChainIdToStartGame_) external onlyOwner {
        require(dstChainIdToStartGame_ > 0, "HoneyJarPortal: dstChainIdToStartGame_ must be > 0");
        dstChainIdToStartGame[dstChainId_] = dstChainIdToStartGame_;
    }

    // Revisit debit logic, could BURN.  _creditTo would be able to  ignore existence check
    function _debitFrom(address _from, uint16, bytes memory, uint256 _tokenId) internal override {
        if (_from != _msgSender()) revert OwnerNotCaller();
        honeyJar.safeTransferFrom(_from, address(this), _tokenId); // Performs the owner & approval checks
    }

    function _creditTo(uint16, address _toAddress, uint256 _tokenId) internal override {
        if (_exists(_tokenId) && honeyJar.ownerOf(_tokenId) != address(this)) revert HoneyJarNotInPortal(_tokenId);
        if (!_exists(_tokenId)) {
            honeyJar.mintTokenId(_toAddress, _tokenId); //HoneyJar Portal should have MINTER Perms on HoneyJar
        } else {
            honeyJar.safeTransferFrom(address(this), _toAddress, _tokenId);
        }
    }

    /// @notice should only be called form ETH (ChainId=1) Doens't make sense otherwise.
    function sendStartGame(
        uint16 destChainId_,
        CrossChainBundleConfig calldata bundleConfig_,
        address payable refundAddress_,
        address zroPaymentAddress_,
        bytes memory adapterParams_
    ) internal virtual {
        if (otherPortals[destChainId_] == address(0)) revert PortalDoesNotExist(destChainId_);

        bytes memory payload = abi.encode(otherPortals[destChainId_], MessageTypes.START_GAME, bundleConfig_);

        _checkGasLimit(destChainId_, FUNCTTION_TYPE_START, adapterParams_, dstChainIdToStartGame[destChainId_]);
        _lzSend(destChainId_, payload, refundAddress_, zroPaymentAddress_, adapterParams_, msg.value);

        emit StartCrossChainGame(destChainId_, bundleConfig_);
    }

    /// @notice slightly modified version of the _send method in ONFTCore. Overloaded with additional parameters to comply with additional xChain messaging
    function _send(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256[] memory _tokenIds,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal override {
        // allow 1 by default
        require(_tokenIds.length > 0, "LzApp: tokenIds[] is empty");
        require(
            _tokenIds.length == 1 || _tokenIds.length <= dstChainIdToBatchLimit[_dstChainId],
            "ONFT721: batch size exceeds dst batch limit"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _debitFrom(_from, _dstChainId, _toAddress, _tokenIds[i]);
        }

        // Adding message types to payload
        bytes memory payload = abi.encode(MessageTypes.SEND_NFT, _toAddress, _tokenIds);

        _checkGasLimit(
            _dstChainId, FUNCTION_TYPE_SEND, _adapterParams, dstChainIdToTransferGas[_dstChainId] * _tokenIds.length
        );
        _lzSend(_dstChainId, payload, _refundAddress, _zroPaymentAddress, _adapterParams, msg.value);
        emit SendToChain(_dstChainId, _from, _toAddress, _tokenIds);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        // TODO: figure out how to decode payload properly.
        (MessageTypes msgType, bytes memory remainingPayload) = abi.decode(_payload, (MessageTypes, bytes));

        if (msgType == MessageTypes.SEND_NFT) {
            _processSendNFTMessage(_srcChainId, _srcAddress, remainingPayload);
        } else if (msgType == MessageTypes.START_GAME) {
            // Do something
            _processStartGame(_srcChainId, remainingPayload);
        } else {
            emit MessageRecieved(_payload);
        }
    }

    function _processStartGame(uint16 srcChainid, bytes memory payload) internal {
        CrossChainBundleConfig memory bundleConfig = abi.decode(payload, (CrossChainBundleConfig));
    }

    /// @notice a copy of the OFNFT721COre _nonBlockingrcv to keep NFT functionality the same.
    function _processSendNFTMessage(uint16 _srcChainId, bytes memory _srcAddress, bytes memory _payload) internal {
        (bytes memory toAddressBytes, uint256[] memory tokenIds) = abi.decode(_payload, (bytes, uint256[]));

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        uint256 nextIndex = _creditTill(_srcChainId, toAddress, 0, tokenIds);
        if (nextIndex < tokenIds.length) {
            // not enough gas to complete transfers, store to be cleared in another tx
            bytes32 hashedPayload = keccak256(_payload);
            storedCredits[hashedPayload] = StoredCredit(_srcChainId, toAddress, nextIndex, true);
            emit CreditStored(hashedPayload, _payload);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, tokenIds);
    }

    function onERC721Received(address _operator, address, uint256, bytes memory)
        public
        view
        override
        returns (bytes4)
    {
        // only allow `this` to transfer token from others
        if (_operator != address(this)) return bytes4(0);
        return IERC721Receiver.onERC721Received.selector;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return honeyJar.ownerOf(tokenId) != address(0);
    }
}
