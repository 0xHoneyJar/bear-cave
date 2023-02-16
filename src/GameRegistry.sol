// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "./GameLib.sol";

/// @title GameRegistry
/// @notice Central repository that tracks games and permissions.
/// @dev All game contracts should use extend `GameRegistryConsumer` to have consistent permissioning
contract GameRegistry is AccessControl {
    uint256 public earlyAccessTime = 72 hours;

    struct Game {
        bool enabled;
        uint256 generalMintTime; // timestamp when generalMint
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Constants.GAME_ADMIN, msg.sender);
    }

    mapping(address => Game) public games;

    function registerGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.GAME_INSTANCE, game_);
    }

    function startGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.MINTER, game_);
        games[game_] = Game(true, block.timestamp + earlyAccessTime);
    }

    function stopGame(address game_) external onlyRole(Constants.GAME_ADMIN) {
        _revokeRole(Constants.MINTER, game_);
        games[game_].enabled = false;
    }

    /**
     * Bear Pouch setters (helper functions)
     * Can check roles directly since this is an access control
     */

    function setJani(address jani_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.JANI, jani_);
    }

    function setBeekeeper(address beeKeeper_) external onlyRole(Constants.GAME_ADMIN) {
        _grantRole(Constants.JANI, beeKeeper_);
    }

    function setEarlyAccessTime(uint256 earlyAccessTime_) external onlyRole(Constants.GAME_ADMIN) {
        earlyAccessTime = earlyAccessTime_;
    }
}

abstract contract GameRegistryConsumer {
    GameRegistry public gameRegistry;

    error GameRegistry_NoPermissions(string role, address user);

    modifier onlyRole(bytes32 role_) {
        if (!gameRegistry.hasRole(role_, msg.sender)) {
            revert GameRegistry_NoPermissions(string(abi.encodePacked(role_)), msg.sender);
        }
        _;
    }

    constructor(address gameRegistry_) {
        gameRegistry = GameRegistry(gameRegistry_);
    }

    function _isEnabled(address game_) internal view returns (bool enabled) {
        (enabled, ) = gameRegistry.games(game_);
    }

    // TODO: Use the game registry to track game states
    function _isGeneralMintEnabled(address game_) internal view returns (bool enabled) {
        (, uint256 generalMintTime) = gameRegistry.games(game_);
        return block.timestamp >= generalMintTime;
    }

    function _hasRole(bytes32 role_) internal view returns (bool) {
        return gameRegistry.hasRole(role_, msg.sender);
    }
}
