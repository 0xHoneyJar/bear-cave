// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {ONFT721Core} from "@layerzero/token/onft/ONFT721Core.sol";

import {LibString} from "solmate/utils/LibString.sol";
import {Constants} from "./Constants.sol";
import {GameRegistryConsumer} from "./GameRegistryConsumer.sol";

import {IHoneyJar} from "./IHoneyJar.sol";

/// @title HoneyJarPortal
/// @dev Modeled off of @layerzero/token/onft/extension/ProxyONFT721.sol
contract HoneyJarPortal is GameRegistryConsumer, ONFT721Core {
    using ERC165Checker for address;

    IHoneyJar public honeyJar;

    constructor(
        uint256 _minGasToTransfer,
        address _lzEndpoint,
        address _honeyJar,
        address _gameRegistry
    ) ONFT721Core(_minGasToTransfer, _lzEndpoint) GameRegistryConsumer(_gameRegistry) {
        require(_proxyToken.supportsInterface(type(IERC721).interfaceId), "ProxyONFT721: invalid ERC721 token");
        honeyJar = IERC721(_proxyToken);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    // TODO: Revisit debit logic, could BURN.  _creditTo would be able to  ignore existence check
    function _debitFrom(address _from, uint16, bytes memory, uint _tokenId) internal virtual override {
        honeyJar.safeTransferFrom(_from, address(this), _tokenId); // Performs the owner & approval checks
    }

    function _creditTo(uint16, address _toAddress, uint _tokenId) internal virtual override {
        require(!_exists(_tokenId) || (_exists(_tokenId) && honeyJar.ownerOf(_tokenId) == address(this)));
        if (!_exists(_tokenId)) {
            honeyJar.mintTokenId(_toAddress, _tokenId); //HoneyJar Portal should have MINTER Perms on HoneyJar
        } else {
            honeyJar.safeTransferFrom(address(this), _toAddress, _tokenId);
        }
    }

    function onERC721Received(address _operator, address, uint, bytes memory) public virtual override returns (bytes4) {
        // only allow `this` to transfer token from others
        if (_operator != address(this)) return bytes4(0);
        return IERC721Receiver.onERC721Received.selector;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return honeyJar.ownerOf(tokenId) != address(0);
    }
}
