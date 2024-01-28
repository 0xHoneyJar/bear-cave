// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBearPouch {
    /// @notice struct that describes recipient and how much to distribute
    struct DistributionConfig {
        address recipient;
        uint256 share;
    }
    /// @notice method to distribute funds to configured beras
    /// @param amount the amount of the ERC20 token to distribute as well

    function distribute(uint256 amount) external payable;
}
