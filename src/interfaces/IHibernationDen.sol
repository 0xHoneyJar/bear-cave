// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// TODO: add other external methods to this interface
interface IHibernationDen {
    function startGame(uint256 srcChainId, uint8 bundleId_, uint256 numSleepers_, uint256[] calldata checkpoints)
        external;
    function setCrossChainFermentedJars(uint8 bundleId, uint256[] calldata fermentedJarIds) external;
}
