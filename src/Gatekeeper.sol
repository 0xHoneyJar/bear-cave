// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import "solmate/auth/Owned.sol";
import "solmate/utils/MerkleProofLib.sol";

import {IHoneyComb} from "src/IHoneyComb.sol";

/**
 * Bear GateKeeper
 *      In order to remain gas-efficient gates will be calculated off-chain
 *      Bearlock: owning bears
 *      FrenLock: owning particular assets
 *      PartnerLock: being on a traditional allowlist
 *      Since gates are merkle trees, the per-player amounts will be set off-chain in the root.
 */
// Gatekeeper should be pass through, and claimed amounts should be stored in the cave.
contract Gatekeeper is Owned {
    struct Gate {
        bool active;
        uint32 claimedCount; // # of claims already happend (this won't be reusable for other bears... ._.)
        uint32 maxClaimable; // # of claims per gate
        bytes32 gateRoot;
    }

    /**
     * Configuration
     */
    bytes32 public allowRoot; // High level tree to determine if you're allowed through
    uint32 public maxClaimable; // Max claimable per player
    address gameContract;

    /**
     * Internal Storage
     */
    mapping(uint256 => mapping(address => uint32)) public assetToClaimed; // bear --> player --> numClaimed

    /**
     * Dependencies
     */
    Gate[] public gates;
    IHoneyComb public honeyComb;

    /// @notice admin is the address that is set as the owner.
    /// @param maxClaimable_ maxClaimable honeycomb per player
    constructor(uint32 maxClaimable_, address honeyComb_) Owned(msg.sender) {
        maxClaimable = maxClaimable_;
        honeyComb = IHoneyComb(honeyComb_);
    }

    /// @notice validate how much you can claim for a particular token and gate. (not a real claim)
    /// @param tokenId the ID of the bear in the game.
    /// @param index the gate index we're claiming
    /// @param amount number between 0-maxClaimablel you a player wants to claim
    /// @param proof merkle proof
    function claim(uint256 tokenId, uint256 index, address player, uint32 amount, bytes32[] calldata proof)
        external
        view
        returns (uint32 claimAmount)
    {
        require(index < gates.length, "Index too big bro");

        Gate memory gate = gates[index];
        require(gate.active, "gates closed bruh");
        require(assetToClaimed[tokenId][player] < maxClaimable, "You've taken as much free honey as you can ");
        require(gate.claimedCount < gate.maxClaimable, "Too much honeycomb went through this gate");

        claimAmount = amount;
        bytes32 leaf = keccak256(abi.encodePacked(player, amount));
        bool validProof = MerkleProofLib.verify(proof, gates[index].gateRoot, leaf);
        require(validProof, "Not a valid proof bro");

        uint32 claimedAmount = assetToClaimed[tokenId][player];
        if (amount + claimedAmount > maxClaimable) {
            claimAmount = maxClaimable - claimedAmount;
        }
    }

    /// @notice simple function that accepts a proof + player and validates if its elegible for a claim
    function gatekeep(address player_, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(player_));
        return MerkleProofLib.verify(proof, allowRoot, leaf);
    }

    /**
     * Setters
     */

    /// @notice  update accounting
    /// @dev should only be called by a game
    function addClaimed(uint256 tokenId_, uint256 gateId, address player_, uint32 numClaimed_) external {
        require(msg.sender == gameContract, "ser u are not a game");
        assetToClaimed[tokenId_][player_] += numClaimed_;
        gates[gateId].claimedCount += numClaimed_;
    }

    /**
     * Gatekeeper admins
     */

    function setGameContract(address gameContract_) external onlyOwner {
        require(gameContract_ != address(0), "setGameContract::invalidAddress");
        gameContract = gameContract_;
    }

    function setAllowRoot(bytes32 root_) external onlyOwner {
        allowRoot = root_;
    }

    function setMaxClaimable(uint32 maxClaimable_) external onlyOwner {
        maxClaimable = maxClaimable_;
    }

    /**
     * Gate admin methods
     */

    function addGate(bytes32 root_, uint32 maxClaimable_) external onlyOwner {
        gates.push(Gate(true, 0, maxClaimable_, root_));
    }

    function setGateActive(uint256 index, bool active) external onlyOwner {
        gates[index].active = active;
    }

    function setGateMaxClaimable(uint256 index, uint32 maxClaimable_) external onlyOwner {
        gates[index].maxClaimable = maxClaimable_;
    }

    function resetGate(uint256 index) external onlyOwner {
        gates[index].claimedCount = 0;
    }
}

/**
 * Unused
 */
/// @notice Base class that all other gatekeeper derive from. Contain rules for if & how many a 26 is allowed to claim
/// @dev instances of this class fully own the logic for if/how a player is elegible for the list.
/// This class owns claim status as well as allowlist status. (if you can claim you you're allowed in)
abstract contract VirtualGate is Owned {
    struct Player {
        bool allowed;
        bool claimed;
        uint32 numClaimable;
    }

    mapping(address => Player) public players;

    uint32 public maxClaimable;
    bytes32 public proofRoot; // All gates can use merkleTrees

    /// @param maxClaimable_ the max claimable per PLAYER
    constructor(uint32 maxClaimable_) Owned(msg.sender) {
        maxClaimable = maxClaimable_;
    }

    function check(address player_, uint32 amount_, bytes32[] calldata proof)
        external
        view
        virtual
        returns (Player memory playerInfo);

    function isValidLeaf(address player_, uint32 amount_, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = _createLeaf(player_, amount_);
        return MerkleProofLib.verify(proof, proofRoot, leaf);
    }

    function _createLeaf(address player_, uint32 amount_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(player_, amount_));
    }

    function open(address player_, uint32 amount_, bytes32[] calldata proof) external {
        bool isValid = isValidLeaf(player_, amount_, proof);
        require(isValid, "not a valid claim proof");
        players[player_].allowed = true;
    }

    function claim(address player_, uint32 amount_, bytes32[] calldata proof) external {
        bool isValid = isValidLeaf(player_, amount_, proof);
        require(isValid, "not a valid claim proof");
        players[player_].claimed = true;
    }
}
