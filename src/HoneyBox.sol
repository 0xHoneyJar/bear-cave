// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/ReentrancyGuard.sol";

import "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";

import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {Constants} from "src/Constants.sol";
import {IHoneyJar} from "src/IHoneyJar.sol";

/// @title HoneyBox
/// @notice Revision of v1/BearCave.sol
contract HoneyBox is VRFConsumerBaseV2, ERC1155TokenReceiver, ReentrancyGuard, GameRegistryConsumer {
    using SafeTransferLib for IERC20;
    using FixedPointMathLib for uint256;

    /// @notice the lone sleepooor
    struct SleepingNFT {
        IERC721 token;
        IERC1155 erc1155Token;
        uint256 tokenId; // The ID of the sleeping NF
        uint256 specialHoneyJar; // defaults to 0
        uint256 publicMintTime; // block.timestamp that general public can start making honeyJars
        bool specialHoneyJarFound; // When tokenID=0 can't wake before special honeyJar is found
        bool isAwake; // don't try to wake if its already awake
    }

    /// @notice The bundle Config
    struct SlumberParty {
        uint8 bundleId;
        uint256 specialHoneyJar; // defaults to 0
        uint256 publicMintTime; // block.timestamp that general public can start making honeyJars
        bool specialHoneyJarFound; // So tokenID=0 can't wake bear before special honey is found
        bool isAwake;
        SleepingNFT[] sleepoors;
    }

    // TODO: how does this config chage for xChain?
    struct MintConfig {
        uint32 maxHoneycomb; // Max # of generated honeys (Max of 4.2m)
        uint32 maxClaimableHoneycomb; // # of honeyJars that can be claimed (total)
        uint256 honeyJarPrice_ERC20;
        uint256 honeyJarPrice_ETH;
    }

    /**
     *  Game Errors
     */
    // Contract State
    error NotInitialized();
    error AlreadyInitialized();
    error ZeroAddress(string key);
    error ExpectedFlag(string key, bool value);

    // Game state
    error BearAlreadyWoke(uint256 bearId);
    error GameInProgress();
    error AlreadyTooManyHoneyJars(uint256 bearId);
    error SpecialHoneyJarNotFound(uint256 bearId);
    error NotEnoughHoneyJarMinted(uint256 bearId);
    error GeneralMintNotOpen(uint256 bearId);
    error BearNotHibernating(uint256 bearId);
    error ZeroBalance();

    // User Errors
    error NotOwnerOfSpecialHoneyJar(uint256 bearId, uint256 honeyJarId);
    error Claim_IncorrectInput();
    error Claim_InvalidProof();
    error MekingTooManyHoneyJars(uint256 bearId);
    error NoPermissions_ERC1155();
    error ZeroMint();
    error WrongAmount_ETH(uint256 expected, uint256 actual);
    error Withdraw_NoPermissions();

    /**
     * Events
     */
    event Initialized(MintConfig mintConfig);
    event BearHibernated(uint256 tokenId);
    event SpecialHoneyJarFound(uint256 tokenId, uint256 honeyJarId);
    event MintConfigChanged(MintConfig mintConfig);
    event HoneycombClaimed(uint256 tokenId, address player, uint256 amount);
    event BearAwoke(uint256 tokenId, address player);

    /**
     * Configuration
     */
    IERC20 public paymentToken; // OHM
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
    address payable private beekeeper; // rev share 22.33%
    address payable private jani;
    uint256 public honeyJarShare; // as a WAD

    /**
     * Dependencies
     */
    Gatekeeper public gatekeeper;
    IHoneyJar public honeyJar;
    VRFCoordinatorV2Interface internal vrfCoordinator;

    /**
     * Internal Storage
     */
    bool public initialized;
    mapping(uint8 => SlumberParty) public slumberParties; //  bundleId --> bundloor
    mapping(uint8 => uint32) public claimed; // bundleId -> numClaimed (free claims)
    mapping(uint256 => uint8) public rng; // Chainlink VRF request ID => bundleID

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
    /// @param keyhash_ from https://docs.chain.link/docs/vrf-contracts/#configurations
    /// @param subId_ Subscription ID from vrf.chain.link
    /// @param jani_ address for THJ rev
    /// @param beekeeper_ address THJ rev-share
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
    function getSlumberParty(uint16 _bundleId) external view returns (SlumberParty memory) {
        return slumberParties[_bundleId];
    }

    /// @notice Bundles need to be preconfigured using addBundle from gameAdmin
    function puffPuffPassOut(uint8 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        SlumberParty slumberParty = slumberParties[bundleId_]; // Will throw index out of bounds if not valid bundleId_
        uint256 sleeperCount = slumberParty.sleepoors.length;
        SleepingNFT[] storage sleepoors = slumberParty.sleepoors;
        SleepingNFT storage sleepoor;
        for (uint256 i = 0; i < sleeperCount; ++i) {
            sleepoor = sleepoors[i];
            if (address(sleepoor.token) != address(0)) {
                //  ERC721
                token.safeTransferFrom(msg.sender, address(this), sleepoor.tokenId);
            }
            if (address(sleepoor.erc1155Token) != token(0)) {
                // ERC1155
                erc1155.safeTransferFrom(msg.sender, address(this), sleepoor.tokenId, 1, "");
            }

            sleepoor.publicMintTime = block.timestamp + 72 hours; // TODO: should be reading from config?
            gatekeeper.startGatesForToken(bundleId_);
        }

        emit SlumberPartyStarted(bundleId_);
    }

    // TODO: need to write this function.
    function addBundle(uint256 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        if (!erc1155.isApprovedForAll(msg.sender, address(this))) revert NoPermissions_ERC1155();
        erc1155.safeTransferFrom(msg.sender, address(this), bundleId_, 1, "");

        bears[bundleId_] = HibernatingBear(bundleId_, 0, block.timestamp + 72 hours, false, false);

        emit BearHibernated(bundleId_);
    }

    /// @dev internal helper function to perform conditional checks for minting state
    function _canMintHoneycomb(uint256 bundleId_, uint256 amount_) internal view {
        if (!initialized) revert NotInitialized();
        HibernatingBear memory bear = bears[bundleId_];

        if (bear.id != bundleId_) revert BearNotHibernating(bundleId_);
        if (bear.isAwake) revert BearAlreadyWoke(bundleId_);
        if (honeyJar[bundleId_].length > mintConfig.maxHoneycomb) revert AlreadyTooManyHoneyJars(bundleId_);
        if (honeyJar[bundleId_].length + amount_ > mintConfig.maxHoneycomb) revert MekingTooManyHoneyJars(bundleId_);
        if (amount_ == 0) revert ZeroMint();
    }

    /// @notice Allows players to mint honeyJar with a valid proof
    /// @param proofAmount the amount of free claims you are entitled to in the claim
    /// @param proof The proof from the gate that allows the player to mint
    /// @param mintAmount actual amount of honeyJars you want to mint.
    function earlyMekHoneyJarWithERC20(
        uint256 bearId,
        uint32 gateId,
        uint32 proofAmount,
        bytes32[] calldata proof,
        uint256 mintAmount
    ) external returns (uint256) {
        if (mintAmount == 0) revert ZeroMint();

        _canMintHoneycomb(bearId, mintAmount);
        // validateProof checks that gates are open
        bool validProof = gatekeeper.validateProof(bearId, gateId, msg.sender, proofAmount, proof);
        if (!validProof) revert Claim_InvalidProof();
        return _distributeERC20AndMintHoneycomb(bearId, mintAmount);
    }

    /// @notice Allows players to mint honeyJar with a valid proof (Taking ETH as payment)
    /// @param proofAmount the amount of free claims you are entitled to in the claim
    /// @param proof The proof from the gate that allows the player to mint
    /// @param mintAmount actual amount of honeyJars you want to mint.
    function earlyMekHoneyJarWithEth(
        uint256 bearId,
        uint32 gateId,
        uint32 proofAmount,
        bytes32[] calldata proof,
        uint256 mintAmount
    ) external payable returns (uint256) {
        _canMintHoneycomb(bearId, mintAmount);
        // validateProof checks that gates are open
        bool validProof = gatekeeper.validateProof(bearId, gateId, msg.sender, proofAmount, proof); // This shit needs to be bulletproof
        if (!validProof) revert Claim_InvalidProof();
        return _distributeETHAndMintHoneycomb(bearId, mintAmount);
    }

    function mekHoneyJarWithERC20(uint256 bundleId_, uint256 amount_) external returns (uint256) {
        _canMintHoneycomb(bundleId_, amount_);
        if (bears[bundleId_].publicMintTime > block.timestamp) revert GeneralMintNotOpen(bundleId_);
        return _distributeERC20AndMintHoneycomb(bundleId_, amount_);
    }

    function mekHoneyJarWithETH(uint256 bundleId_, uint256 amount_) external returns (uint256) {
        _canMintHoneycomb(bundleId_, amount_);
        if (bears[bundleId_].publicMintTime > block.timestamp) revert GeneralMintNotOpen(bundleId_);

        return _distributeETHAndMintHoneycomb(bundleId_, amount_);
    }

    /// @dev internal helper function to collect payment and mint honeyJar
    /// @return tokenID of minted honeyJar
    function _distributeERC20AndMintHoneycomb(uint256 bundleId_, uint256 amount_) internal returns (uint256) {
        uint256 price = mintConfig.honeyJarPrice_ERC20;
        _distribute(price * amount_);

        // Mint da honey
        return _mintHoneyJarForBear(msg.sender, bundleId_, amount_);
    }

    /// @dev internal helper function to collect payment and mint honeyJar
    /// @return tokenID of minted honeyJar
    function _distributeETHAndMintHoneycomb(uint256 bundleId_, uint256 amount_) internal returns (uint256) {
        uint256 price = mintConfig.honeyJarPrice_ETH;
        if (msg.value != price * amount_) revert WrongAmount_ETH(price * amount_, msg.value);

        _distribute(0);

        return _mintHoneyJarForBear(msg.sender, bundleId_, amount_);
    }

    /// @notice internal method to mint for a particular user
    /// @param to user to mint to
    /// @param bearId_ the bea being minted for
    function _mintHoneyJarForBear(address to, uint256 bearId_, uint256 amount_) internal returns (uint256) {
        uint256 tokenId = honeyJar.nextTokenId();
        honeyJar.batchMint(to, amount_);

        // Have a unique tokenId for a given bearId
        for (uint256 i = 0; i < amount_; ++i) {
            honeyJar[bearId_].push(tokenId);
            honeyJarToBear[tokenId] = bearId_;
            ++tokenId;
        }

        // Find the special honeyJar when the last honeyJar is minted.
        if (honeyJar[bearId_].length >= mintConfig.maxHoneycomb) {
            _findHoneyJar(bearId_);
        }

        return tokenId - 1; // returns the lastID created
    }

    /// @notice this function _should_ only be called in case of emergencies
    /// @notice if the honeyJars are minted but the VRF called failed.
    /// @dev kicks off another VRF request
    function forceHoneycombSearch(uint256 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        if (honeyJar[bundleId_].length < mintConfig.maxHoneycomb) revert NotEnoughHoneyJarMinted(bundleId_);
        _findHoneyJar(bundleId_);
    }

    /// @notice Forcing function to find a bear.
    /// @notice Should only be called when the last honeyJars is minted.
    function _findHoneyJar(uint256 bundleId_) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(keyHash, subId, minConfirmations, callbackGasLimit, 2);
        rng[requestId] = bundleId_;
    }

    /// @notice the callback method that is called when VRF completes
    /// @param requestId requestId that is generated when initiaully calling VRF
    /// @param randomness an array of random numbers based on `numWords` config
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        /// use requestID to get bearId
        uint256 bearId = rng[requestId];
        _setSpecialHoneyJar(bearId, randomness[0]);
    }

    /// @notice helper function to set a random honeyJar as a winner
    /// @param bearId self-explanatory
    /// @param randomNumber used to determine the index of the winning number
    function _setSpecialHoneyJar(uint256 bearId, uint256 randomNumber) internal {
        uint256 numHoneyJars = honeyJar[bearId].length;
        uint256 specialHoneyIndex = randomNumber % numHoneyJars;
        uint256 specialHoneyJarId = honeyJar[bearId][specialHoneyIndex];

        HibernatingBear storage bear = bears[bearId];
        bear.specialHoneycombFound = true;
        bear.specialHoneycombId = specialHoneyJarId;

        emit SpecialHoneyJarFound(bearId, specialHoneyJarId);
    }

    function openBox(uint256 bearId_) external {
        // Check that msg.sender has the special honeyJar to wake up bear
        HibernatingBear memory bear = bears[bearId_];

        if (bear.isAwake) revert BearAlreadyWoke(bearId_);
        if (honeyJar[bearId_].length < mintConfig.maxHoneycomb) revert NotEnoughHoneyJarMinted(bearId_);
        if (!bear.specialHoneycombFound) revert SpecialHoneyJarNotFound(bearId_);

        if (honeyJar.ownerOf(bear.specialHoneycombId) != msg.sender) {
            revert NotOwnerOfSpecialHoneyJar(bearId_, bear.specialHoneycombId);
        }

        // Send over bear
        erc1155.safeTransferFrom(address(this), msg.sender, bear.id, 1, "");

        emit BearAwoke(bearId_, msg.sender);
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

    function _splitFee(uint256 currentBalance) internal view returns (uint256) {
        return currentBalance.mulWadUp(honeyJarShare);
    }

    /**
     * Gatekeeper: for claiming free honeyJar
     * BearCave:
     *    - maxMintableHoneyJar per Bear
     *    - claimedHoneyJar per Bear // free
     *    - maxClaimableHoneyJar per Bear
     * Gatekeeper: (per bear)
     * Gates:
     *    - maxHoneycombAvailable per gate
     *    - maxClaimable per gate
     *
     */

    function claim(uint256 bundleId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) public {
        // Gatekeeper tracks per-player/per-gate claims
        if (proof.length == 0) revert Claim_InvalidProof();
        uint32 numClaim = gatekeeper.claim(bundleId_, gateId, msg.sender, amount, proof);
        if (numClaim == 0) {
            return;
        }

        // Track per bear freeClaims
        uint32 claimedAmount = claimed[bundleId_];
        if (numClaim + claimedAmount > mintConfig.maxClaimableHoneycomb) {
            numClaim = mintConfig.maxClaimableHoneycomb - claimedAmount;
        }

        _canMintHoneycomb(bundleId_, numClaim); // Validating here because numClaims can change

        // If for some reason this fails, GG no honeyJar for you
        _mintHoneyJarForBear(msg.sender, bundleId_, numClaim);

        claimed[bundleId_] += numClaim;
        // Can be combined with "claim" call above, but keeping separate to separate view + modification on gatekeeper
        gatekeeper.addClaimed(bundleId_, gateId, numClaim, proof);

        emit HoneycombClaimed(bundleId_, msg.sender, numClaim);
    }

    /// @dev Helper function to process all free cams. More client-sided computation.
    function claimAll(
        uint256 bundleId_,
        uint32[] calldata gateId,
        uint32[] calldata amount,
        bytes32[][] calldata proof
    ) external {
        uint256 inputLength = proof.length;
        if (inputLength != gateId.length) revert Claim_IncorrectInput();
        if (inputLength != amount.length) revert Claim_IncorrectInput();

        for (uint256 i = 0; i < inputLength; ++i) {
            if (proof[i].length == 0) continue; // Don't nomad yourself
            claim(bundleId_, gateId[i], amount[i], proof[i]);
        }
    }

    //=============== SETTERS ================//

    /**
     * Bear Pouch setters (needed for distribution)
     *  Currently separate from the permissioned roles in gameRegistry
     */

    /// @notice THJ address
    function setJani(address jani_) external onlyRole(Constants.GAME_ADMIN) {
        jani = payable(jani_);
    }

    /// @notice RevShare address
    function setBeeKeeper(address beekeeper_) external onlyRole(Constants.GAME_ADMIN) {
        beekeeper = payable(beekeeper_);
    }

    /**
     * Game setters
     *  These should not be called while a game is in progress to prevent hostage holding.
     */

    /// @notice Sets the max number NFTs (honeyJar) that can be generated from the deposit of a bear (asset)
    function setMaxHoneycomb(uint32 _maxHoneycomb) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.maxHoneycomb = _maxHoneycomb;

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
    /// @notice Chainlink SubscriptionID
    function setSubId(uint64 subId_) external onlyRole(Constants.GAME_ADMIN) {
        subId = subId_;
    }

    /// @notice Keyhash from https://docs.chain.link/docs/vrf-contracts/#configurations
    function setKeyHash(bytes32 keyHash_) external onlyRole(Constants.GAME_ADMIN) {
        keyHash = keyHash_;
    }
}
