// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "solmate/utils/MerkleProofLib.sol";

import {GameRegistryConsumer} from "./GameRegistry.sol";
import {Constants} from "./GameLib.sol";

/**
 * Bear GateKeeper
 *      In order to remain gas-efficient gates will be calculated off-chain
 *      BearGate: owning bears
 *      CrownGate: every single one of the digital collectible articles, then they get a free claim in every game
 *      HoneyGate: Genesis mint & n-1 can mint
 *      FrenGate: owning particular assets
 *      PartnerGate: being on a traditional allowlist
 *      Since gates are merkle trees, the per-player amounts will be set off-chain in the root.
 *  @notice state needs to be reset after each game.
 *  @notice tracks claims per player, and claims per gate.
 */
contract Gatekeeper is GameRegistryConsumer {
    struct Gate {
        bool active;
        uint32 claimedCount; // # of claims already happend (this won't be reusable for other bears... ._.)
        uint32 maxClaimable; // # of claims per gate
        bytes32 gateRoot;
    }

    /**
     * Internal Storage
     */
    mapping(uint256 => Gate[]) public tokenToGates; // bear -> Gates[]
    mapping(uint256 => address) public games; // bear --> gameContract;

    /**
     * Dependencies
     */
    /// @notice admin is the address that is set as the owner.
    constructor(address gameRegistry_) GameRegistryConsumer(gameRegistry_) {}

    /// @notice validate how much you can claim for a particular token and gate. (not a real claim)
    /// @param tokenId the ID of the bear in the game.
    /// @param index the gate index we're claiming
    /// @param amount number between 0-maxClaimablel you a player wants to claim
    /// @param proof merkle proof
    function claim(
        uint256 tokenId,
        uint256 index,
        address player,
        uint32 amount,
        bytes32[] calldata proof
    ) external view returns (uint32 claimAmount) {
        Gate[] memory gates = tokenToGates[tokenId];
        require(gates.length > 0, "nogates fren");
        require(index < gates.length, "Index too big bro");

        Gate memory gate = gates[index];

        require(gate.active, "gates closed bruh");
        uint32 claimedCount = gate.claimedCount;
        require(claimedCount < gate.maxClaimable, "Too much honeycomb went through this gate");

        // validate proof
        claimAmount = amount;
        bytes32 leaf = keccak256(abi.encodePacked(player, amount));
        bool validProof = MerkleProofLib.verify(proof, gates[index].gateRoot, leaf);
        require(validProof, "Not a valid proof bro");

        if (amount + claimedCount > gate.maxClaimable) {
            claimAmount = gate.maxClaimable - claimedCount;
        }
    }

    /**
     * Setters
     */

    /// @notice  update accounting
    /// @dev should only be called by a game
    function addClaimed(
        uint256 tokenId,
        uint256 gateId,
        uint32 numClaimed_
    ) external onlyRole(Constants.GAME_INSTANCE) {
        tokenToGates[tokenId][gateId].claimedCount += numClaimed_;
    }

    /**
     * Gate admin methods
     */

    function addGate(uint256 tokenId, bytes32 root_, uint32 maxClaimable_) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[tokenId].push(Gate(true, 0, maxClaimable_, root_));
    }

    function setGateActive(uint256 tokenId, uint256 index, bool active) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[tokenId][index].active = active;
    }

    function setGateMaxClaimable(
        uint256 tokenId,
        uint256 index,
        uint32 maxClaimable_
    ) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[tokenId][index].maxClaimable = maxClaimable_;
    }

    function resetGate(uint256 tokenId, uint256 index) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[tokenId][index].claimedCount = 0;
    }
}
