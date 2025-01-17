// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";

import {IGatekeeper} from "src/interfaces/IGatekeeper.sol";
import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Constants} from "src/Constants.sol";

/**
 * GateKeeper
 *  @notice state needs to be reset after each game.
 *  @notice tracks claims per player, and claims per gate.
 */
contract Gatekeeper is GameRegistryConsumer, IGatekeeper {
    /**
     * Errors
     */
    error TooMuchHoneyJarInGate(uint256 gateId);
    error GatekeeperInvalidProof();
    error NoGates();
    error Gate_OutOfBounds(uint256 gateId);
    error Gate_NotEnabled(uint256 gateId);
    error Gate_NotActive(uint256 gateId, uint256 activeAt);
    error Stage_OutOfBounds(uint256 stageId);
    error ConsumedProof();

    /**
     * Events when business logic is affects
     */
    event GateAdded(uint256 bundleId, uint256 gateId);
    event GateSetEnabled(uint256 bundleId, uint256 gateId, bool enabled);
    event GateTimeUpdated(uint256 bundleId, uint256 gateId, uint256 activeAt);
    event GateActivated(uint256 bundleId, uint256 gateId, uint256 activationTime);
    event GetSetMaxClaimable(uint256 bundleId, uint256 gateId, uint256 maxClaimable);
    event GateReset(uint256 bundleId, uint256 index);
    event GateRootUpdated(uint256 bundleId, uint256 index, bytes32 gateRoot);

    /**
     * Internal Storage
     */
    mapping(uint256 => Gate[]) public tokenToGates; // bundle -> Gates[]
    mapping(uint256 => mapping(bytes32 => bool)) public consumedProofs; // gateId --> proof --> boolean
    mapping(uint256 => bytes32[]) public consumedProofsList; // gateId --> consumed proofs (needed for resets)

    // There will only be one bundle -- don't need mapping from bundle to gate here.
    mapping(uint256 => mapping(address => uint32)) public minted; // mapping of player to amount minted

    /**
     * Dependencies
     */
    /// @notice admin is the address that is set as the owner.
    constructor(address gameRegistry_) GameRegistryConsumer(gameRegistry_) {}

    /// @notice helper function for FE to
    /// @dev if activeAt is 0 this method will also return true
    function isGateOpen(uint256 bundleId, uint256 gateId) external view returns (bool) {
        return block.timestamp > tokenToGates[bundleId][gateId].activeAt;
    }

    /// @inheritdoc IGatekeeper
    function calculateClaimable(
        uint256 bundleId,
        uint256 index,
        uint256 proofIndex,
        address player,
        uint32 claimableAllowance,
        uint32 mintAllowance,
        bytes32[] calldata proof
    ) external view returns (uint32 claimAmount) {
        // If proof was already used within the gate, there are 0 left to claim
        bytes32 proofHash = keccak256(abi.encode(proof));
        if (consumedProofs[index][proofHash]) return 0;

        Gate storage gate = tokenToGates[bundleId][index];
        uint32 claimedCount = gate.claimedCount;
        if (claimedCount >= gate.maxClaimable) revert TooMuchHoneyJarInGate(index);

        claimAmount = claimableAllowance;
        bool validProof = validateProof(bundleId, index, proofIndex, player, claimableAllowance, mintAllowance, proof);
        if (!validProof) revert GatekeeperInvalidProof();

        if (claimableAllowance + claimedCount > gate.maxClaimable) {
            claimAmount = gate.maxClaimable - claimedCount;
        }
    }

    function calculateMintable(
        uint256 bundleId,
        uint256 index,
        uint256 proofIndex,
        address player,
        uint32 claimAllowance,
        uint32 mintAllowance,
        bytes32[] calldata proof
    ) external view returns (uint32 mintAmount) {
        Gate storage gate = tokenToGates[bundleId][index];

        // Set the mint to be the allowance
        mintAmount = mintAllowance;
        bool validProof = validateProof(bundleId, index, proofIndex, player, claimAllowance, mintAllowance, proof);
        if (!validProof) revert GatekeeperInvalidProof();

        // remove the amount the player has already minted
        mintAmount -= minted[index][player];
    }

    /// @inheritdoc IGatekeeper
    function validateProof(
        uint256 bundleId,
        uint256 index,
        uint256 proofIndex,
        address player,
        uint32 claimAllowance,
        uint32 mintAllowance,
        bytes32[] calldata proof
    ) public view returns (bool validProof) {
        Gate[] storage gates = tokenToGates[bundleId];
        if (gates.length == 0) revert NoGates();
        if (index >= gates.length) revert Gate_OutOfBounds(index);
        if (proof.length == 0) revert GatekeeperInvalidProof();

        Gate storage gate = gates[index];
        if (!gate.enabled) revert Gate_NotEnabled(index);
        if (gate.activeAt > block.timestamp) revert Gate_NotActive(index, gate.activeAt);

        bytes32 leaf = keccak256(abi.encodePacked(proofIndex, player, claimAllowance, mintAllowance));
        validProof = MerkleProofLib.verify(proof, gate.gateRoot, leaf);
    }

    /**
     * State modifiers
     */

    /// @inheritdoc IGatekeeper
    function addClaimed(uint256 bundleId, uint256 gateId, uint32 numClaimed, bytes32[] calldata proof)
        external
        onlyRole(Constants.GAME_INSTANCE)
    {
        Gate storage gate = tokenToGates[bundleId][gateId];
        bytes32 proofHash = keccak256(abi.encode(proof));

        if (!gate.enabled) revert Gate_NotEnabled(gateId);
        if (gate.activeAt > block.timestamp) revert Gate_NotActive(gateId, gate.activeAt);
        if (consumedProofs[gateId][proofHash]) revert ConsumedProof();

        gate.claimedCount += numClaimed;

        consumedProofs[gateId][proofHash] = true;
        consumedProofsList[gateId].push(proofHash);
    }

    function addMinted(uint256 bundleId, uint256 gateId, address player, uint32 numMinted)
        external
        onlyRole(Constants.GAME_INSTANCE)
    {
        Gate storage gate = tokenToGates[bundleId][gateId];

        if (!gate.enabled) revert Gate_NotEnabled(gateId);
        if (gate.activeAt > block.timestamp) revert Gate_NotActive(gateId, gate.activeAt);

        minted[gateId][player] += numMinted;
    }

    /**
     * Gate admin methods
     */

    /// @inheritdoc IGatekeeper
    function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        external
        onlyRole(Constants.GAME_ADMIN)
    {
        if (stageIndex_ >= _getStages().length) revert Stage_OutOfBounds(stageIndex_);
        // ClaimedCount = 0, activeAt = 0 (updated when gates are started)
        tokenToGates[bundleId].push(Gate(false, stageIndex_, 0, maxClaimable_, root_, 0));

        emit GateAdded(bundleId, tokenToGates[bundleId].length - 1);
    }

    /// @inheritdoc IGatekeeper
    function startGatesForBundle(uint256 bundleId) external onlyRole(Constants.GAME_INSTANCE) {
        Gate[] storage gates = tokenToGates[bundleId];
        uint256[] memory stageTimes = _getStages(); // External Call
        uint256 numGates = gates.length;

        if (numGates == 0) revert NoGates(); // Require at least one gate

        for (uint256 i = 0; i < numGates; i++) {
            if (gates[i].enabled) continue;
            gates[i].enabled = true;
            gates[i].activeAt = block.timestamp + stageTimes[gates[i].stageIndex];
            emit GateActivated(bundleId, i, gates[i].activeAt);
        }
    }

    /// @notice Only to be used for emergency gate shutdown/start
    /// @dev if the gate was never enabled by a call to startGatesForBundle, the gates will be enabled immediately.
    function setGateEnabled(uint256 bundleId, uint256 index, bool enabled) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[bundleId][index].enabled = enabled;

        emit GateSetEnabled(bundleId, index, enabled);
    }

    /// @notice admin function that can increase / decrease the amount of free claims available for a specific gate
    function setGateMaxClaimable(uint256 bundleId, uint256 index, uint32 maxClaimable_)
        external
        onlyRole(Constants.GAME_ADMIN)
    {
        tokenToGates[bundleId][index].maxClaimable = maxClaimable_;
        emit GetSetMaxClaimable(bundleId, index, maxClaimable_);
    }

    /// @notice admin function that can change the root of a specific gate
    function setGateRoot(uint256 bundleId, uint256 index, bytes32 newRoot) external onlyRole(Constants.GAME_ADMIN) {
        tokenToGates[bundleId][index].gateRoot = newRoot;

        emit GateRootUpdated(bundleId, index, newRoot);
    }

    /// @notice admin function that can change the start time of a specific gate
    function updateGateTime(uint256 bundleId, uint256 index, uint256 newTimestamp)
        external
        onlyRole(Constants.GAME_ADMIN)
    {
        tokenToGates[bundleId][index].activeAt = newTimestamp;

        emit GateTimeUpdated(bundleId, index, newTimestamp);
    }

    /// @notice helper function to reset gate state for a game
    function resetGate(uint256 bundleId, uint256 index) external onlyRole(Constants.GAME_ADMIN) {
        delete tokenToGates[bundleId][index];

        uint256 numProofs = consumedProofsList[index].length;
        for (uint256 i = 0; i < numProofs; ++i) {
            delete consumedProofs[index][consumedProofsList[index][i]];
        }

        emit GateReset(bundleId, index);
    }

    /// @notice helper function to reset all gates for a particular token
    function resetAllGates(uint256 bundleId) external onlyRole(Constants.GAME_ADMIN) {
        uint256 numGates = tokenToGates[bundleId].length;
        Gate[] storage tokenGates = tokenToGates[bundleId];
        uint256 numProofs;

        // Currently a hacky way but need to clear out if the proofs were used.
        for (uint256 i = 0; i < numGates; i++) {
            tokenGates[i].claimedCount = 0;
            numProofs = consumedProofsList[i].length;
            for (uint256 j = 0; j < numProofs; ++j) {
                // Step through all proofs from a particular gate.
                delete consumedProofs[i][consumedProofsList[i][j]];
            }

            emit GateReset(bundleId, i);
        }
    }
}
