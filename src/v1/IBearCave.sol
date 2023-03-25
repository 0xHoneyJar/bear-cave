// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title BearCave: Only one true honey can make a bear wake up
interface IBearCave {
    struct HibernatingBear {
        uint256 id;
        uint256 specialHoneycombId; // defaults to 0
        uint256 publicMintTime; // block.timestamp that general public can start making honeycombs
        bool specialHoneycombFound; // So tokenID=0 can't wake bear before special honey is found
        bool isAwake; // don't try to wake if its already awake
    }

    struct MintConfig {
        uint32 maxHoneycomb; // Max # of generated honeys (Max of 4.2m)
        uint32 maxClaimableHoneycomb; // # of honeycombs that can be claimed (total)
        uint256 honeycombPrice_ERC20;
        uint256 honeycombPrice_ETH;
    }

    /// @notice Puts the bear into the cave to mek it sleep
    /// @dev Should be permissioned to be onlyOwner
    /// @param bearId_ ID of the bear to mek sleep
    function hibernateBear(uint256 bearId_) external;

    /// @notice Meks honey for `_bearID` that could wake it up. Will revert if user does not have the funds.
    /// @param bearId_ ID of the bear the honeycomb will wake up
    function mekHoneyCombWithERC20(uint256 bearId_, uint256 amount) external returns (uint256);

    /// @notice Same as `mekHoneyCombWithERC20` however this function accepts ETH payments
    /// @param bearId_ ID of the bear the honeycomb will wake up
    function mekHoneyCombWithEth(uint256 bearId_, uint256 amount) external payable returns (uint256);

    /// @notice Takes special honey comb to wake up the bear
    /// @param bearId_ ID of the bear to wake up
    function wakeBear(uint256 bearId_) external;

    /// @notice for claiming free honeycomb
    /// @param bearId_ the ERC1155 Token ID of the bong bear
    /// @param gateId index of the gate
    /// @param amount amount being claimed by the player
    /// @param proof that the player is elgible to claim.
    function claim(uint256 bearId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) external;
}
