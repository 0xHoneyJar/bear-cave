// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library Constants {
    // External permissions
    enum GAME_ROLES {
        GAME_ADMIN,
        BEEKEEPER,
        JANI,
        GAME_INSTANCE,
        BEAR_POUCH,
        GATEKEEPER,
        GATE,
        MINTER,
        BURNER
    }

    /**
        Below is needed for existing honeycomb roles. 
     */
    bytes32 internal constant GAME_ADMIN = "GAME_ADMIN";
    bytes32 internal constant BEEKEEPER = "BEEKEEPER";
    bytes32 internal constant JANI = "JANI";

    // Contract instances
    bytes32 internal constant GAME_INSTANCE = "GAME_INSTANCE";
    bytes32 internal constant BEAR_POUCH = "BEAR_POUCH";
    bytes32 internal constant GATEKEEPER = "GATEKEEPER";
    bytes32 internal constant GATE = "GATE";

    // Special honeycomb permissions
    bytes32 internal constant MINTER = "MINTER";
    bytes32 internal constant BURNER = "BURNER";
}
