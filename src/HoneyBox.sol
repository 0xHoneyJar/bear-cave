// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Switching to OZ for LZ compatibility
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/VRFConsumerBaseV2.sol";

import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/Constants.sol";
import {IHoneyJar} from "src/IHoneyJar.sol";

/// @title HoneyBox
/// @notice Revision of v1/BearCave.sol
/// @notice Manages bundling & storage of NFTs. Mints honeyJar ERC721s
contract HoneyBox is VRFConsumerBaseV2, ERC721TokenReceiver, ERC1155TokenReceiver, GameRegistryConsumer {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /// @notice the lone sleepooor (single NFT)
    struct SleepingNFT {
        address tokenAddress;
        uint256 tokenId; // The ID of the sleeping NFT
        bool isERC1155;
    }

    /// @notice The bundle Config (Collection)
    struct SlumberParty {
        uint8 bundleId;
        uint256 specialHoneyJar; // defaults to 0
        uint256 publicMintTime; // block.timestamp that general public can start making honeyJars
        bool specialHoneyJarFound; // So tokenID=0 can't wake bear before special honey is found
        bool isAwake;
        SleepingNFT[] sleepoors;
    }

    /// @notice Configuration for minting for games occurring at the same time.
    struct MintConfig {
        uint32 maxHoneyJar; // Max # of generated honeys (Max of 4.2m)
        uint32 maxClaimableHoneyJar; // # of honeyJars that can be claimed (total)
        uint256 honeyJarPrice_ERC20;
        uint256 honeyJarPrice_ETH;
    }

    /**
     *  Game Errors
     */
    // Contract State
    error NotInitialized();
    error AlreadyInitialized();

    // Game state
    error PartyAlreadyWoke(uint8 bundleId);
    error GameInProgress();
    error AlreadyTooManyHoneyJars(uint8 bundleId);
    error SpecialHoneyJarNotFound(uint8 bundleId);
    error NotEnoughHoneyJarMinted(uint8 bundleId);
    error GeneralMintNotOpen(uint8 bundleId);
    error NotSleeping(uint8 bundleId);

    // User Errors
    error NotOwnerOfSpecialHoneyJar(uint8 bundleId, uint256 honeyJarId);
    error InvalidInput(string method);
    error Claim_InvalidProof();
    error MekingTooManyHoneyJars(uint8 bundleId);
    error ZeroMint();
    error WrongAmount_ETH(uint256 expected, uint256 actual);

    /**
     * Events
     */
    event Initialized(MintConfig mintConfig);
    event SlumberPartyStarted(uint8 bundleId);
    event SlumberPartyAdded(uint8 bundleId);
    event SpecialHoneyJarFound(uint8 bundleId, uint256 honeyJarId);
    event MintConfigChanged(MintConfig mintConfig);
    event VRFConfigChanged(VRFConfig vrfConfig);
    event HoneyJarClaimed(uint256 bundleId, address player, uint256 amount);
    event PartyAwoke(uint8 bundleId, address player);

    /**
     * Configuration
     */
    IERC20 public immutable paymentToken; // OHM
    MintConfig public mintConfig;

    /**
     * Chainlink VRF Config
     */
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations

    struct VRFConfig {
        bytes32 keyHash;
        uint64 subId; // https://vrf.chain.link/goerli/new
        uint16 minConfirmations; // Default is 3
        uint32 callbackGasLimit; // enough for ~5 words
    }
    VRFConfig private vrfConfig;

    /**
     * bearPouch
     */
    address payable private immutable beekeeper; // rev share
    address payable private immutable jani;
    uint256 public immutable honeyJarShare; // as a WAD

    /**
     * Dependencies
     */
    Gatekeeper public immutable gatekeeper; // TODO: this should be an interface
    IHoneyJar public immutable honeyJar;
    VRFCoordinatorV2Interface internal immutable vrfCoordinator;

    /**
     * Internal Storage
     */
    bool public initialized;
    SlumberParty[] public slumberPartyList; // list of slumberparties
    mapping(uint8 => SlumberParty) public slumberParties; //  bundleId --> bundle
    mapping(uint8 => uint32) public claimed; // bundleId -> numClaimed (free claims)
    mapping(uint256 => uint8) public rng; // Chainlink VRF request ID => bundleID
    mapping(uint256 => uint8) public honeyJarToParty; // Reverse mapping for honeyJar to bundle
    mapping(uint8 => uint256[]) public honeyJarShelf; // List of Honeyjars associated with a particular bundle (SlumberParty)

    constructor(
        address _vrfCoordinator,
        address _gameRegistry,
        address _honeyJarAddress,
        address _paymentToken,
        address _gatekeeper,
        address _jani,
        address _beekeeper,
        uint256 _honeyJarShare
    ) VRFConsumerBaseV2(_vrfCoordinator) GameRegistryConsumer(_gameRegistry) ReentrancyGuard() {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        honeyJar = IHoneyJar(_honeyJarAddress);
        paymentToken = IERC20(_paymentToken);
        gatekeeper = Gatekeeper(_gatekeeper);
        jani = payable(_jani);
        beekeeper = payable(_beekeeper);
        honeyJarShare = _honeyJarShare;
    }

    /// @notice additional parameters that are required to get the game running
    /// @param vrfConfig_ Chainlink  configuration
    /// @param mintConfig_ needed for the specific game
    function initialize(
        VRFConfig calldata vrfConfig_,
        MintConfig calldata mintConfig_
    ) external onlyRole(Constants.GAME_ADMIN) {
        if (initialized) revert AlreadyInitialized();

        initialized = true;
        vrfConfig = vrfConfig_;
        mintConfig = mintConfig_;

        emit Initialized(mintConfig);
    }

    /// @notice Who is partying without me?
    function getSlumberParty(uint8 _bundleId) external view returns (SlumberParty memory) {
        return slumberParties[_bundleId];
    }

    /// @notice Once a bundle is configured, transfers the configured assets into this contract.
    /// @notice Starts the gates within the Gatekeeper, which determine who is allowed early access and free claims
    /// @dev Bundles need to be preconfigured using addBundle from gameAdmin
    /// @dev publicMintTime is hardcoded to be 72 hours after calling this method.
    function puffPuffPassOut(uint8 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        SlumberParty memory slumberParty = slumberParties[bundleId_]; // Will throw index out of bounds if not valid bundleId_
        uint256 sleeperCount = slumberParty.sleepoors.length;
        SleepingNFT[] memory sleepoors = slumberParty.sleepoors;
        SleepingNFT memory sleepoor;
        for (uint256 i = 0; i < sleeperCount; ++i) {
            sleepoor = sleepoors[i];

            if (sleepoor.isERC1155) {
                // ERC1155
                IERC1155(sleepoor.tokenAddress).safeTransferFrom(msg.sender, address(this), sleepoor.tokenId, 1, "");
            } else {
                //  ERC721
                IERC721(sleepoor.tokenAddress).safeTransferFrom(msg.sender, address(this), sleepoor.tokenId);
            }
        }

        slumberParties[bundleId_].publicMintTime = block.timestamp + 72 hours;
        gatekeeper.startGatesForToken(bundleId_);
        emit SlumberPartyStarted(bundleId_);
    }

    /// @notice method stores the configuration for the sleeping NFTs
    // bundleId --> bundle --> []nfts
    function addBundle(
        address[] calldata tokenAddresses_,
        uint256[] calldata tokenIds_,
        bool[] calldata isERC1155_
    ) external onlyRole(Constants.GAME_ADMIN) returns (uint8) {
        uint256 inputLength = tokenAddresses_.length;
        if (inputLength == 0 || inputLength != tokenIds_.length || inputLength != isERC1155_.length)
            revert InvalidInput("addBundle");

        uint8 bundleId = uint8(slumberPartyList.length); // Will fail if we have >255 bundles

        // Add to the bundle mapping & list
        SlumberParty storage slumberParty = slumberPartyList.push(); // 0 initialized Bundle
        slumberParty.bundleId = bundleId;

        // Synthesize sleeper configs from input
        for (uint256 i = 0; i < inputLength; ++i) {
            slumberParty.sleepoors.push(SleepingNFT(tokenAddresses_[i], tokenIds_[i], isERC1155_[i]));
        }

        slumberParties[bundleId] = slumberParty; // Save to mapping

        emit SlumberPartyAdded(bundleId);
        return bundleId;
    }

    /// @dev internal helper function to perform conditional checks for minting state
    function _canMintHoneyJar(uint8 bundleId_, uint256 amount_) internal view {
        if (!initialized) revert NotInitialized();
        SlumberParty memory party = slumberParties[bundleId_];

        if (party.bundleId != bundleId_) revert NotSleeping(bundleId_);
        if (party.isAwake) revert PartyAlreadyWoke(bundleId_);
        if (honeyJarShelf[bundleId_].length > mintConfig.maxHoneyJar) revert AlreadyTooManyHoneyJars(bundleId_);
        if (honeyJarShelf[bundleId_].length + amount_ > mintConfig.maxHoneyJar)
            revert MekingTooManyHoneyJars(bundleId_);
        if (amount_ == 0) revert ZeroMint();
    }

    /// @notice Allows players to mint honeyJar with a valid proof
    /// @param proofAmount the amount of free claims you are entitled to in the claim
    /// @param proof The proof from the gate that allows the player to mint
    /// @param mintAmount actual amount of honeyJars you want to mint.
    function earlyMekHoneyJarWithERC20(
        uint8 bundleId,
        uint32 gateId,
        uint32 proofAmount,
        bytes32[] calldata proof,
        uint256 mintAmount
    ) external returns (uint256) {
        if (mintAmount == 0) revert ZeroMint();

        _canMintHoneyJar(bundleId, mintAmount);
        // validateProof checks that gates are open
        bool validProof = gatekeeper.validateProof(bundleId, gateId, msg.sender, proofAmount, proof);
        if (!validProof) revert Claim_InvalidProof();
        return _distributeERC20AndMintHoneyJar(bundleId, mintAmount);
    }

    /// @notice Allows players to mint honeyJar with a valid proof (Taking ETH as payment)
    /// @param proofAmount the amount of free claims you are entitled to in the claim
    /// @param proof The proof from the gate that allows the player to mint
    /// @param mintAmount actual amount of honeyJars you want to mint.
    function earlyMekHoneyJarWithEth(
        uint8 bundleId,
        uint32 gateId,
        uint32 proofAmount,
        bytes32[] calldata proof,
        uint256 mintAmount
    ) external payable returns (uint256) {
        _canMintHoneyJar(bundleId, mintAmount);
        // validateProof checks that gates are open
        bool validProof = gatekeeper.validateProof(bundleId, gateId, msg.sender, proofAmount, proof); // This shit needs to be bulletproof
        if (!validProof) revert Claim_InvalidProof();
        return _distributeETHAndMintHoneyJar(bundleId, mintAmount);
    }

    function mekHoneyJarWithERC20(uint8 bundleId_, uint256 amount_) external returns (uint256) {
        _canMintHoneyJar(bundleId_, amount_);
        if (slumberParties[bundleId_].publicMintTime > block.timestamp) revert GeneralMintNotOpen(bundleId_);
        return _distributeERC20AndMintHoneyJar(bundleId_, amount_);
    }

    function mekHoneyJarWithETH(uint8 bundleId_, uint256 amount_) external returns (uint256) {
        _canMintHoneyJar(bundleId_, amount_);
        if (slumberParties[bundleId_].publicMintTime > block.timestamp) revert GeneralMintNotOpen(bundleId_);

        return _distributeETHAndMintHoneyJar(bundleId_, amount_);
    }

    /// @dev internal helper function to collect payment and mint honeyJar
    /// @return tokenID of minted honeyJar
    function _distributeERC20AndMintHoneyJar(uint8 bundleId_, uint256 amount_) internal returns (uint256) {
        uint256 price = mintConfig.honeyJarPrice_ERC20;
        _distribute(price * amount_);

        // Mint da honey
        return _mintHoneyJarForBear(msg.sender, bundleId_, amount_);
    }

    /// @dev internal helper function to collect payment and mint honeyJar
    /// @return tokenID of minted honeyJar
    function _distributeETHAndMintHoneyJar(uint8 bundleId_, uint256 amount_) internal returns (uint256) {
        uint256 price = mintConfig.honeyJarPrice_ETH;
        if (msg.value != price * amount_) revert WrongAmount_ETH(price * amount_, msg.value);

        _distribute(0);

        return _mintHoneyJarForBear(msg.sender, bundleId_, amount_);
    }

    /// @notice internal method to mint for a particular user
    /// @param to user to mint to
    /// @param bundleId_ the bea being minted for
    function _mintHoneyJarForBear(address to, uint8 bundleId_, uint256 amount_) internal returns (uint256) {
        uint256 tokenId = honeyJar.nextTokenId();
        honeyJar.batchMint(to, amount_);

        // Have a unique tokenId for a given bundleId
        for (uint256 i = 0; i < amount_; ++i) {
            honeyJarShelf[bundleId_].push(tokenId);
            honeyJarToParty[tokenId] = bundleId_;
            ++tokenId;
        }

        // Find the special honeyJar when the last honeyJar is minted.
        if (honeyJarShelf[bundleId_].length >= mintConfig.maxHoneyJar) {
            _findHoneyJar(bundleId_);
        }

        return tokenId - 1; // returns the lastID created
    }

    /// @notice this function _should_ only be called in case of emergencies
    /// @notice if the honeyJars are minted but the VRF called failed.
    /// @dev kicks off another VRF request
    function forceHoneyJarSearch(uint8 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        if (honeyJarShelf[bundleId_].length < mintConfig.maxHoneyJar) revert NotEnoughHoneyJarMinted(bundleId_);
        _findHoneyJar(bundleId_);
    }

    /// @notice Forcing function to find a bear.
    /// @notice Should only be called when the last honeyJars is minted.
    function _findHoneyJar(uint8 bundleId_) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            vrfConfig.keyHash,
            vrfConfig.subId,
            vrfConfig.minConfirmations,
            vrfConfig.callbackGasLimit,
            2
        );
        rng[requestId] = bundleId_;
    }

    /// @notice the callback method that is called when VRF completes
    /// @param requestId requestId that is generated when initially calling VRF
    /// @param randomness an array of random numbers based on `numWords` config
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        /// use requestID to get bundleId
        uint8 bundleId = rng[requestId];
        _setSpecialHoneyJar(bundleId, randomness[0]);
    }

    /// @notice helper function to set a random honeyJar as a winner
    /// @param bundleId self-explanatory
    /// @param randomNumber used to determine the index of the winning number
    function _setSpecialHoneyJar(uint8 bundleId, uint256 randomNumber) internal {
        uint256 numHoneyJars = honeyJarShelf[bundleId].length;
        uint256 specialHoneyIndex = randomNumber % numHoneyJars;
        uint256 specialHoneyJarId = honeyJarShelf[bundleId][specialHoneyIndex];

        SlumberParty storage party = slumberParties[bundleId];
        party.specialHoneyJarFound = true;
        party.specialHoneyJar = specialHoneyJarId;

        emit SpecialHoneyJarFound(bundleId, specialHoneyJarId);
    }

    /// @notice transfers sleeping NFTs to msg.sender if they hold the special honeyJar
    function openHotBox(uint8 bundleId_) external {
        // Check that msg.sender has the special honeyJar
        SlumberParty memory party = slumberParties[bundleId_];

        if (honeyJarShelf[bundleId_].length < mintConfig.maxHoneyJar) revert NotEnoughHoneyJarMinted(bundleId_);
        if (party.isAwake) revert PartyAlreadyWoke(bundleId_);
        if (!party.specialHoneyJarFound) revert SpecialHoneyJarNotFound(bundleId_);

        if (honeyJar.ownerOf(party.specialHoneyJar) != msg.sender) {
            revert NotOwnerOfSpecialHoneyJar(bundleId_, party.specialHoneyJar);
        }

        SleepingNFT[] memory sleepoors = party.sleepoors;
        uint256 sleeperCount = sleepoors.length;

        SleepingNFT memory sleepoor;
        for (uint256 i = 0; i < sleeperCount; ++i) {
            sleepoor = sleepoors[i];

            if (sleepoor.isERC1155) {
                // ERC1155
                IERC1155(sleepoor.tokenAddress).safeTransferFrom(address(this), msg.sender, sleepoor.tokenId, 1, "");
            } else {
                //  ERC721
                IERC721(sleepoor.tokenAddress).safeTransferFrom(address(this), msg.sender, sleepoor.tokenId);
            }
        }

        slumberParties[bundleId_].isAwake = true;
        emit PartyAwoke(bundleId_, msg.sender);
    }

    /**
     * BearPouch owner methods
     *      Can move into another contract for portability
     * depends on:
     *     Exclusive: beekeeper, jani, honeyJarShare
     *     shared: paymentToken
     */

    /// @dev requires that beekeeper and jani addresses are set.
    /// @param amountERC20 is zero if we're only distributing the ETH
    function _distribute(uint256 amountERC20) internal {
        uint256 beekeeperShareERC20 = amountERC20.mulWadUp(honeyJarShare);
        uint256 beekeeperShareETH = (msg.value).mulWadUp(honeyJarShare);

        if (beekeeperShareERC20 != 0) {
            paymentToken.safeTransferFrom(msg.sender, beekeeper, beekeeperShareERC20);
            paymentToken.safeTransferFrom(msg.sender, jani, amountERC20 - beekeeperShareERC20);
        }

        if (beekeeperShareETH != 0) {
            SafeTransferLib.safeTransferETH(beekeeper, beekeeperShareETH);
            SafeTransferLib.safeTransferETH(jani, msg.value - beekeeperShareETH);
        }
    }

    /**
     * Gatekeeper: for claiming free honeyJar
     * BearCave:
     *    - maxMintableHoneyJar per bundle
     *    - claimedHoneyJar per bundle // free
     *    - maxClaimableHoneyJar per bundle
     * Gatekeeper: (per bear)
     * Gates:
     *    - maxhoneyJarAvailable per gate
     *    - maxClaimable per gate
     *
     */

    /// @notice Allows a player to claim free HoneyJar based on elegibility (FCFS)
    /// @dev free claims are determined by the gatekeeper and the accounting is done in this method
    /// @param gateId id of gate from Gatekeeper.
    /// @param amount amount player is claiming
    /// @param proof valid proof that entitles msg.sender to amount.
    function claim(uint8 bundleId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) public {
        // Gatekeeper tracks per-player/per-gate claims
        if (proof.length == 0) revert Claim_InvalidProof();
        uint32 numClaim = gatekeeper.claim(bundleId_, gateId, msg.sender, amount, proof);
        if (numClaim == 0) {
            return;
        }

        // Track per bear freeClaims
        uint32 claimedAmount = claimed[bundleId_];
        if (numClaim + claimedAmount > mintConfig.maxClaimableHoneyJar) {
            numClaim = mintConfig.maxClaimableHoneyJar - claimedAmount;
        }

        _canMintHoneyJar(bundleId_, numClaim); // Validating here because numClaims can change

        // If for some reason this fails, GG no honeyJar for you
        _mintHoneyJarForBear(msg.sender, bundleId_, numClaim);

        claimed[bundleId_] += numClaim;
        // Can be combined with "claim" call above, but keeping separate to separate view + modification on gatekeeper
        gatekeeper.addClaimed(bundleId_, gateId, numClaim, proof);

        emit HoneyJarClaimed(bundleId_, msg.sender, numClaim);
    }

    /// @dev Helper function to process all free cams. More client-sided computation.
    function claimAll(
        uint8 bundleId_,
        uint32[] calldata gateId,
        uint32[] calldata amount,
        bytes32[][] calldata proof
    ) external {
        uint256 inputLength = proof.length;
        if (inputLength != gateId.length) revert InvalidInput("claimAll");
        if (inputLength != amount.length) revert InvalidInput("claimAll");

        for (uint256 i = 0; i < inputLength; ++i) {
            if (proof[i].length == 0) continue; // Don't nomad yourself
            claim(bundleId_, gateId[i], amount[i], proof[i]);
        }
    }

    //=============== SETTERS ================//

    /**
     * Game setters
     *  These should not be called while a game is in progress to prevent hostage holding.
     */

    /// @notice Sets the max number NFTs (honeyJar) that can be generated from the deposit of a bear (asset)
    function setMaxhoneyJar(uint32 _maxhoneyJar) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.maxHoneyJar = _maxhoneyJar;

        emit MintConfigChanged(mintConfig);
    }

    /// @notice sets the price of the honeyJar in `paymentToken`
    function setHoneyJarPrice_ERC20(uint256 _honeyJarPrice) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.honeyJarPrice_ERC20 = _honeyJarPrice;

        emit MintConfigChanged(mintConfig);
    }

    /// @notice sets the price of the honeyJar in `ETH`
    function setHoneyJarPrice_ETH(uint256 _honeyJarPrice) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.honeyJarPrice_ETH = _honeyJarPrice;

        emit MintConfigChanged(mintConfig);
    }

    /**
     * Chainlink Setters
     */

    /// @notice Set from the following docs: https://docs.chain.link/docs/vrf-contracts/#configurations
    function setVRFConfig(VRFConfig calldata vrfConfig_) external onlyRole(Constants.GAME_ADMIN) {
        vrfConfig = vrfConfig_;
        emit VRFConfigChanged(vrfConfig);
    }
}
