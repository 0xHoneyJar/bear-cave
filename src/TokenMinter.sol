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

    constructor(MintConfig mintConfig_, IHoneyJar token_) {
        mintConfig = mintConfig_;
        token = token_;
    }

    /// @notice method to mint the specified NFT
    /// @notice permissioned method to be called by contract that performs the mint eligibility
    function mekToken(uint256 amount_) external payable returns (uint256) {
        bearPouch.distribute{value: msg.value}(mintConfig.tokenPrice_ERC20 * amount_);
        _mintToken(msg.sender, amount_);
    }

    function _mintToken(address to, uint256 amount_) {
        uint256 tokenId = honeyJar.nextTokenId();
        honeyJar.batchMint(to, amount_);

        // TODO: how does this accounting happen in the refactored world?
        // Have a unique tokenId for a given bundleId
        for (uint256 i = 0; i < amount_; ++i) {
            honeyJarShelf[bundleId_].push(tokenId);
            honeyJarToParty[tokenId] = bundleId_;
            ++tokenId;
        }

        // Find the special honeyJar when a checkpoint is passed.
        uint256 numMinted = honeyJarShelf[bundleId_].length;
        SlumberParty storage party = slumberParties[bundleId_];
        if (numMinted >= party.checkpoints[party.checkpointIndex]) {
            _fermentJars(bundleId_);
        }

        return tokenId - 1; // returns the lastID created
    }
}
