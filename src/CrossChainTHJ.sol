// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract CrossChainTHJ {
    struct CrossChainBundleConfig {
        /// @dev unique ID representing the bundle
        uint8 bundleId;
        /// @dev Number of sleepers within a game.
        uint256 numSleepers;
    }

    uint256 private immutable _chainId;

    function getChainId() internal view returns (uint256) {
        return _chainId;
    }

    constructor() {
        _chainId = block.chainid;
    }
}
