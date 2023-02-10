// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {IHoneyComb} from "./IHoneyComb.sol";
import {GameRegistryConsumer} from "./GameRegistry.sol";
import {Constants} from "./GameLib.sol";

contract HoneyComb is IHoneyComb, ERC721, GameRegistryConsumer {
    using LibString for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private lastHoneyId; // atomically increasing tokenId

    constructor(address gameRegistry_) ERC721("Honey Comb", "HONEYCOMB") GameRegistryConsumer(gameRegistry_) {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://0xhoneyjar.com/";
    }

    function tokenURI(uint256 _id) public pure override returns (string memory) {
        return string.concat(_baseURI(), "/honeycomb/", _id.toString());
    }

    /// @notice create honeycomb for an address.
    /// @dev only callable by the MINTER role
    function mint(address to) public onlyRole(Constants.MINTER) returns (uint256) {
        uint256 tokenId = lastHoneyId.current();

        // Fuck ERC721SafeMint since it requires ERC721 rcv to be implemented
        _mint(to, tokenId);

        // If everything else works update storage.
        lastHoneyId.increment();

        return tokenId;
    }

    /// @notice mint multiple.
    /// @dev only callable by the MINTER role
    function batchMint(address to, uint8 amount) external onlyRole(Constants.MINTER) {
        for (uint256 i = 0; i < amount; ++i) {
            mint(to);
        }
    }

    /// @notice burn the honeycomb tokens. Nothing will have the burn role upon initialization
    /// @dev only callable by the BURNER role
    function burn(uint256 _id) external override onlyRole(Constants.BURNER) {
        _burn(_id);
    }
}
