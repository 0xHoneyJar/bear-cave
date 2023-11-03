// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IHoneyJar} from "src/interfaces/IHoneyJar.sol";

contract TokenMinter {
    struct MintConfig {
        /// @dev number of free tokens that can be minted. Should be sum(gates.maxClaimable)
        uint32 maxClaimableToken;
        /// @dev value of the honeyJar in ERC20 -- Ohm is 1e9
        uint256 tokenPrice_ERC20;
        /// @dev value of the token in the native chain token
        uint256 tokenPrice_native;
    }

    MintConfig public mintConfig;
    IHoneyJar public token;
    uint256 public amountMinted;

    constructor(MintConfig memory mintConfig_, IHoneyJar token_) {
        mintConfig = mintConfig_;
        token = token_;
    }

    /// @notice method to mint the specified NFT
    /// @notice permissioned method to be called by contract that performs the mint eligibility
    function mekToken(uint256 amount_) external payable returns (uint256) {
        return _mintToken(msg.sender, amount_);
    }

    function _mintToken(address to, uint256 amount_) internal returns (uint256) {
        token.batchMint(to, amount_);

        amountMinted += amount_;
        return amountMinted - 1; // returns the lastID created
    }
}
