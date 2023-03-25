// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return "MockERC721";
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    function burn(uint256 id) public {
        _burn(id);
    }
}
