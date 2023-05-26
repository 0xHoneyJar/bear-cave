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

interface IHibernationDen {
    function startGame(uint256 srcChainId, uint8 bundleId_, uint256 numSleepers_) external;
    function setCrossChainFermentedJars(uint8 bundleId, uint256[] calldata fermentedJarIds) external;
}

/// @title HoneyJarPortal
/// @notice Manages cross chain business logic and interactions with HoneyJar NFT
/// @dev Modeled off of @layerzero/token/onft/extension/ProxyONFT721.sol
/// @dev setTrustedRemote must be called when initializing`
contract HoneyJarPortal is GameRegistryConsumer, CrossChainTHJ, ONFT721Core, IERC721Receiver {
    using ERC165Checker for address;

    uint16 public constant FUNCTTION_TYPE_START = 2;

    // Events
    event PortalSet(uint256 chainId, address portalAddress);
    event StartCrossChainGame(uint256 chainId, uint8 bundleId, uint256 numSleepers);
    event MessageRecieved(bytes payload);
    event HibernationDenSet(address honeyBoxAddress);
    event StartGameProcessed(uint16 srcChainId, StartGamePayload);
    event FermentedJarsProcessed(uint16 srcChainId, FermentedJarsPayload);
    event LzMappingSet(uint256 evmChainId, uint16 lzChainId);

    // Errors
    error InvalidToken(address tokenAddress);
    error HoneyJarNotInPortal(uint256 tokenId);
    error OwnerNotCaller();
    error LzMappingMissing(uint256 chainId);

    enum MessageTypes {
        SEND_NFT,
        START_GAME,
        SET_FERMENTED_JARS
    }

    // Dependencies
    IHoneyJar public immutable honeyJar;
    IHibernationDen public honeyBox;

    // Internal State
    /// @notice mapping of chainId --> lzChainId
    /// @dev see https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
    mapping(uint256 => uint16) public lzChainId;

    constructor(
        uint256 _minGasToTransfer,
        address _lzEndpoint,
        address _honeyJar,
        address _honeyBox,
        address _gameRegistry
    ) ONFT721Core(_minGasToTransfer, _lzEndpoint) GameRegistryConsumer(_gameRegistry) {
        if (!_honeyJar.supportsInterface(type(IERC721).interfaceId)) revert InvalidToken(_honeyJar);
        honeyJar = IHoneyJar(_honeyJar);
        honeyBox = IHibernationDen(_honeyBox);

        // Initial state
        // https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids#polygon-zkevm
        lzChainId[1] = 101; // mainnet
        lzChainId[5] = 10121; //Goerli
        lzChainId[42161] = 110; // Arbitrum
        lzChainId[421613] = 10143; //Atrbitrum goerli
        lzChainId[10] = 111; //Optimism
        lzChainId[420] = 10132; // Optimism Goerli
        lzChainId[137] = 109; // Polygon
        lzChainId[80001] = 10109; // Mumbai
        lzChainId[1101] = 158; // Polygon zkEVM
        lzChainId[1442] = 10158; // Polygon zkEVM testnet
        lzChainId[10106] = 106; // Avalanche - Fuji
    }

    function setLzMapping(uint256 evmChainId, uint16 lzChainId_) external onlyRole(Constants.GAME_ADMIN) {
        lzChainId[evmChainId] = lzChainId_;
    }

    /// @dev there can only be one honeybox per portal.
    function setHibernationDen(address honeyBoxAddress_) external onlyRole(Constants.GAME_ADMIN) {
        honeyBox = IHibernationDen(honeyBoxAddress_);

        emit HibernationDenSet(honeyBoxAddress_);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    ////////////////////////////////////////////////////////////
    //////////////////  ONFT Transfer        ///////////////////
    ////////////////////////////////////////////////////////////

    /// @notice burns the token that is bridges. Contract needs BURNER role
    function _debitFrom(address _from, uint16, bytes memory, uint256 _tokenId) internal override {
        if (_from != _msgSender()) revert OwnerNotCaller();
        honeyJar.burn(_tokenId);
    }

    function _creditTo(uint16, address _toAddress, uint256 _tokenId) internal override {
        // This shouldn't happen, but just in case.
        if (_exists(_tokenId) && honeyJar.ownerOf(_tokenId) != address(this)) revert HoneyJarNotInPortal(_tokenId);
        if (!_exists(_tokenId)) {
            honeyJar.mintTokenId(_toAddress, _tokenId); //HoneyJar Portal should have MINTER Perms on HoneyJar
        } else {
            honeyJar.safeTransferFrom(address(this), _toAddress, _tokenId);
        }
    }

    /// @notice slightly modified version of the _send method in ONFTCore.
    /// @dev payload is encoded with messageType to be able to consume different message types.
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

    //////////////////////////////////////////////////////
    //////////////////  Game Methods  //////////////////
    //////////////////////////////////////////////////////

    /// @notice should only be called form ETH (ChainId=1) Doens't make sense otherwise.
    /// @dev can only be called by game instances
    function sendStartGame(uint256 destChainId_, uint8 bundleId_, uint256 numSleepers_, address refundAddress_)
        external
        payable
        onlyRole(Constants.GAME_INSTANCE)
    {
        uint16 lzDestId = lzChainId[destChainId_];
        if (lzDestId == 0) revert LzMappingMissing(destChainId_);
        bytes memory payload = _encodeStartGame(bundleId_, numSleepers_);
        _lzSend(lzDestId, payload, payable(refundAddress_), address(0x0), bytes(""), msg.value); // TODO: estimate gas

        emit StartCrossChainGame(destChainId_, bundleId_, numSleepers_);
    }

    function sendFermentedJars(
        uint256 destChainId_,
        uint8 bundleId_,
        uint256[] calldata fermentedJarIds_,
        address refundAddress_
    ) external payable onlyRole(Constants.GAME_INSTANCE) {
        uint16 lzDestId = lzChainId[destChainId_];
        if (lzDestId == 0) revert LzMappingMissing(destChainId_);
        bytes memory payload = _encodeFermentedJars(bundleId_, fermentedJarIds_);
        _lzSend(lzDestId, payload, payable(refundAddress_), address(0x0), bytes(""), msg.value); // TODO estimate Gas
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        (MessageTypes msgType) = abi.decode(_payload, (MessageTypes));
        address srcAddress;
        assembly {
            srcAddress := mload(add(_srcAddress, 20))
        }

        if (msgType == MessageTypes.SEND_NFT) {
            _processSendNFTMessage(_srcChainId, _srcAddress, _payload);
        } else if (msgType == MessageTypes.START_GAME) {
            _processStartGame(_srcChainId, _payload);
        } else if (msgType == MessageTypes.SET_FERMENTED_JARS) {
            _processFermentedJars(_srcChainId, _payload);
        } else {
            emit MessageRecieved(_payload);
        }
    }

    ////////////////////////////////////////////////////////////
    //////////////////  Message Processing   ///////////////////
    ////////////////////////////////////////////////////////////

    function _processStartGame(uint16 srcChainId, bytes memory _payload) internal {
        StartGamePayload memory payload = _decodeStartGame(_payload);
        honeyBox.startGame(srcChainId, payload.bundleId, payload.bundleId); // TODO: does it matter if srcChainId is lzChainId?

        emit StartGameProcessed(srcChainId, payload);
    }

    function _processFermentedJars(uint16 _srcChainId, bytes memory _payload) internal {
        FermentedJarsPayload memory payload = _decodeFermentedJars(_payload);
        honeyBox.setCrossChainFermentedJars(payload.bundleId, payload.fermentedJarIds);

        emit FermentedJarsProcessed(_srcChainId, payload);
    }

    /// @notice a copy of the OFNFT721COre _nonBlockingrcv to keep NFT functionality the same.
    function _processSendNFTMessage(uint16 _srcChainId, bytes memory _srcAddress, bytes memory _payload) internal {
        SendNFTPayload memory payload = _decodeSendNFT(_payload);

        uint256 nextIndex = _creditTill(_srcChainId, payload.to, 0, payload.tokenIds);
        if (nextIndex < payload.tokenIds.length) {
            // not enough gas to complete transfers, store to be cleared in another tx
            bytes32 hashedPayload = keccak256(_payload);
            storedCredits[hashedPayload] = StoredCredit(_srcChainId, payload.to, nextIndex, true);
            emit CreditStored(hashedPayload, _payload);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, payload.to, payload.tokenIds);
    }

    //////////////////////////////////////////////////////
    //////////////////  Encode/Decode   //////////////////
    //////////////////////////////////////////////////////

    struct StartGamePayload {
        uint8 bundleId;
        uint256 numSleepers;
    }

    struct SendNFTPayload {
        address to;
        uint256[] tokenIds;
    }

    struct FermentedJarsPayload {
        uint8 bundleId;
        uint256[] fermentedJarIds;
    }

    function _encodeStartGame(uint8 bundleId_, uint256 numSleepers_) internal view returns (bytes memory) {
        return abi.encode(MessageTypes.START_GAME, StartGamePayload(bundleId_, numSleepers_));
    }

    function _encodeFermentedJars(uint8 bundleId_, uint256[] memory fermentedJarIds_)
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(MessageTypes.SET_FERMENTED_JARS, FermentedJarsPayload(bundleId_, fermentedJarIds_));
    }

    function _decodeSendNFT(bytes memory _payload) internal pure returns (SendNFTPayload memory payload) {
        (, payload) = abi.decode(_payload, (MessageTypes, SendNFTPayload));
    }

    function _decodeStartGame(bytes memory _payload) internal pure returns (StartGamePayload memory payload) {
        (, payload) = abi.decode(_payload, (MessageTypes, StartGamePayload));
    }

    function _decodeFermentedJars(bytes memory _payload) internal pure returns (FermentedJarsPayload memory) {
        (, FermentedJarsPayload memory payload) = abi.decode(_payload, (MessageTypes, FermentedJarsPayload));
        return payload;
    }

    /////////////////////////////////////////////
    //////////////////  Misc   //////////////////
    /////////////////////////////////////////////

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
