// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";

import {ERC721AQueryable, ERC721A} from "ERC721A/extensions/ERC721AQueryable.sol";

import {IHoneyComb} from "./IHoneyComb.sol";
import {GameRegistryConsumer} from "./GameRegistry.sol";
import {Constants} from "./GameLib.sol";

contract HoneyComb is IHoneyComb, GameRegistryConsumer, ERC721AQueryable {
    using LibString for uint256;

    constructor(address gameRegistry_) ERC721A("Honey Comb", "HONEYCOMB") GameRegistryConsumer(gameRegistry_) {}

    // metadata URI
    string private _baseTokenURI = "https://www.0xhoneyjar.xyz/";

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyRole(Constants.GAME_ADMIN) {
        _baseTokenURI = baseURI;
    }

    /// @notice create honeycomb for an address.
    /// @dev only callable by the MINTER role
    function mint(address to) public onlyRole(Constants.MINTER) returns (uint256) {
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

    /// @notice burn the honeycomb tokens. Nothing will have the burn role upon initialization
    /// @notice This will be used for future game-mechanics
    /// @dev only callable by the BURNER role
    function burn(uint256 _id) external override onlyRole(Constants.BURNER) {
        _burn(_id, true);
    }
}
