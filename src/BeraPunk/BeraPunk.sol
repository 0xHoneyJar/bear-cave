// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MultisigOwnable} from "dual-ownership-nft/MultisigOwnable.sol";
import {LibString} from "solmate/utils/LibString.sol";

import {Constants} from "src/Constants.sol";
import {IBeraPunk} from "src/BeraPunk/IBeraPunk.sol";
import {ERC721AQueryable, ERC721A, IERC721A} from "ERC721A/extensions/ERC721AQueryable.sol";
import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";

contract BeraPunk is IBeraPunk, GameRegistryConsumer, ERC721AQueryable, MultisigOwnable {
    using LibString for uint256;

    constructor(address gameRegistry_) ERC721A("Bera Punk", "BPUNK") GameRegistryConsumer(gameRegistry_) {}

    // metadata URI
    string public _baseTokenURI = "https://www.0xhoneyjar.xyz/";
    bool public isGenerated; // once the token is generated we can append individual tokenIDs

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyRealOwner {
        _baseTokenURI = baseURI;
    }

    function setGenerated(bool generated_) external onlyRealOwner {
        isGenerated = generated_;
    }

    /// @notice Token URI will be a generic URI at first.
    /// @notice When isGnerated is set to true, it will concat the baseURI & tokenID
    function tokenURI(uint256 tokenId) public view override(IERC721A, ERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return isGenerated ? string.concat(baseURI, _toString(tokenId)) : baseURI;
    }

    /// @notice create BeraPunk for an address.
    /// @dev only callable by the MINTER role
    function mintOne(address to) public onlyRole(Constants.MINTER) returns (uint256) {
        _mint(to, 1);
        return _nextTokenId() - 1; // To get the latest mintID
    }

    function nextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    /// @notice mint multiple.
    /// @dev only callable by the MINTER role
    function batchMint(address to, uint256 amount) external onlyRole(Constants.MINTER) {
        _mint(to, amount);
    }

    /// Once a berapunk is alive, it stays alive.
}
