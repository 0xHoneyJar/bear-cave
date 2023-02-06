// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library Random {
    // Returns a random index in the range [0, _max)
    function randomFromMax(uint256 _max) external view returns (uint256) {
        // Generate a random number between 0 and 2^256-1
        uint256 randomNum = random(msg.sender);
        // Return the random number modulo _max
        return randomNum % _max;
    }

    // TODO: Have this shit be a VRFConsumer or something
    // Returns a random number between 0 and 2^256-1
    /// @dev this is the same number for each block per caller. :sadge:
    function random(address _sender) private view returns (uint256) {
        // Seed the random number generator with the block hash
        uint256 seed = uint256(blockhash((block.number - 1)));

        // Return a random number using the sha3 function
        return uint256(keccak256(abi.encodePacked(_sender, seed, block.timestamp, this)));
    }
}
