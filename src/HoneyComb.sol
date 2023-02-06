// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {IHoneyComb} from "./IHoneyComb.sol";

contract HoneyComb is IHoneyComb, ERC721, Owned {
    using LibString for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private lastHoneyId; // atomically increasing tokenId

    constructor() ERC721("Honey Comb", "HONEYCOMB") Owned(msg.sender) {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://0xhoneyjar.com/";
    }

    function tokenURI(uint256 _id) public pure override returns (string memory) {
        return string.concat(_baseURI(), "/honeycomb/", _id.toString());
    }

    function mint(address to) public returns (uint256) {
        uint256 tokenId = lastHoneyId.current();

        // Fuck ERC721SafeMint since it requires ERC721 rcv to be implemented
        _mint(to, tokenId);

        // If everything else works update storage.
        lastHoneyId.increment();

        return tokenId;
    }

    function batchMint(address to, uint8 amount) external {
        for (uint256 i = 0; i < amount; ++i) {
            mint(to);
        }
    }

    // TODO: build this out so we can have ways to burn the honeyComb token
    function burn(uint256 _id) external onlyOwner {
        // TODO: CHANGE THIS PLEASE BECAUSE THIS MEANS THE OWNER CAN DELETE ANY HONEYCOMB
        _burn(_id);
    }
}
