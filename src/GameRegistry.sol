// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "./Constants.sol";

/// @title GameRegistry
/// @notice Central repository that tracks games and permissions.
/// @dev All game contracts should use extend `GameRegistryConsumer` to have consistent permissioning
contract GameRegistry is AccessControl {
    struct Game {
        bool enabled;
    }

    uint256[] public stageTimes;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Constants.GAME_ADMIN, msg.sender);

        // Initial 4 stages
        stageTimes.push(0 hours);
        stageTimes.push(24 hours);
        stageTimes.push(48 hours);
        stageTimes.push(72 hours);
    }

    mapping(address => Game) public games;

    /// @notice registers the game with the GameRegistry and "enables it"
    /// @notice enabling the game means that the game is in "progress"
    function registerGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.GAME_INSTANCE, game_);
        games[game_] = Game(true);
    }

    /// @notice starts the game which grants it the minterRole within the THJ ecosystem
    function startGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.MINTER, game_);
    }

    /// @notice stops the game which removes the mintor role and sets enable = false
    function stopGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _revokeRole(Constants.MINTER, game_);
        games[game_].enabled = false;
    }

    /**
     * Gettors
     */
    function getStageTimes() external view returns (uint256[] memory) {
        return stageTimes;
    }

    /**
     * Bear Pouch setters (helper functions)
     * Can check roles directly since this is an access control
     */

    /// @notice sets the JANI role in the THJ game registry.
    function setJani(address jani_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.JANI, jani_);
    }

    /// @notice sets the beeKeeper role in the THJ game registry.
    function setBeekeeper(address beeKeeper_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.BEEKEEPER, beeKeeper_);
    }

    /// @notice If the stages need to be modified after this contract is created.
    function setStageTimes(uint24[] calldata _stageTimes) external onlyRole(Constants.GAME_ADMIN) {
        stageTimes = _stageTimes;
    }
}
