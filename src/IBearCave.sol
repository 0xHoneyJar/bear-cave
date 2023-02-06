// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// @title BearCave: Only one true honey can make a bear wake up
/// @author ZayenX
interface IBearCave {
    struct HibernatingBear {
        uint256 id;
        uint256 specialHoneycombId; // defaults to 0
        bool specialHoneycombFound; // So tokenID=0 can't wake bear before special honey is found
        bool isAwake; // don't try to wake if its already awake
    }

    /// @notice Puts the bear into the cave to mek it sleep
    /// @dev Should be permissioned to be onlyOwner
    /// @param _bearId ID of the bear to mek sleep
    function hibernateBear(uint256 _bearId) external;

    /// @notice Meks honey for `_bearID` that could wake it up. Will revert if user does not have the funds.
    /// @param _bearId ID of the bear the honey will wake up
    function mekHoneyComb(uint256 _bearId) external returns (uint256); // Makes honey for the bear

    /// @notice Takes special honey to wake up the bear
    /// @param _bearId ID of the bear to wake up
    function wakeBear(uint256 _bearId) external;
}
