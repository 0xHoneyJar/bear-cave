// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {ONFT721Core} from "@layerzero/token/onft/ONFT721Core.sol";

import {GameRegistryConsumer} from "./GameRegistryConsumer.sol";

import {IHoneyJar} from "./IHoneyJar.sol";

/// @title HoneyJarPortal
/// @notice Manages cross chain business logic and interactions with HoneyJar NFT
/// @dev Modeled off of @layerzero/token/onft/extension/ProxyONFT721.sol
/// @dev Is subject to change with v3 development
contract HoneyJarPortal is GameRegistryConsumer, ONFT721Core, IERC721Receiver {
    using ERC165Checker for address;

    IHoneyJar public immutable honeyJar;

    // Errors
    error InvalidToken(address tokenAddress);
    error HoneyJarNotInPortal(uint256 tokenId);
    error OwnerNotCaller();

    constructor(uint256 _minGasToTransfer, address _lzEndpoint, address _honeyJar, address _gameRegistry)
        ONFT721Core(_minGasToTransfer, _lzEndpoint)
        GameRegistryConsumer(_gameRegistry)
    {
        if (!_honeyJar.supportsInterface(type(IERC721).interfaceId)) revert InvalidToken(_honeyJar);
        honeyJar = IHoneyJar(_honeyJar);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
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
