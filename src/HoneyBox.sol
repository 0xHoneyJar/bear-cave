// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/VRFConsumerBaseV2.sol";

import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {CrossChainTHJ} from "src/CrossChainTHJ.sol";
import {IGatekeeper} from "src/IGatekeeper.sol";
import {IHoneyJar} from "src/IHoneyJar.sol";
import {Constants} from "src/Constants.sol";

/// @notice minimal interface for the CrossChainPortal
interface IHoneyJarPortal {
    function sendStartGame(uint16 destChainId_, uint8 bundleId_, uint256 numSleepers_) external;
    function sendFermentedJars(uint16 destChainId_, uint8 bundleId_, uint256[] calldata fermentedJarIds_) external;
}

/// @title HoneyBox
/// @notice Manages bundling & storage of NFTs. Mints honeyJar ERC721s
contract HoneyBox is
    VRFConsumerBaseV2,
    ERC721TokenReceiver,
    ERC1155TokenReceiver,
    GameRegistryConsumer,
    CrossChainTHJ,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using BitMaps for BitMaps.BitMap;

    /// @notice the lone sleepooor (single NFT)
    struct SleepingNFT {
        /// @dev address of the ERC721/ERC1155
        address tokenAddress;
        /// @dev tokenID of the sleeping NFT
        uint256 tokenId;
        /// @dev true if the tokenAddress points to an ERC1155
        bool isERC1155;
    }

    struct FermentedJar {
        /// @dev id of the fermented jar
        uint256 id;
        /// @dev boolean to determine if the user has awoken the sleeping NFT
        bool isUsed;
    }

    /// @notice The bundle Config (Collection)
    struct SlumberParty {
        /// @dev unique ID representing the bundle
        uint8 bundleId;
        /// @dev the block.timestamp when the mint() function can be called. Should be set at game-start
        uint256 publicMintTime;
        /// @dev chainId that can wakeSleeper
        uint16 assetChainId;
        /// @dev The chainId that can mint
        uint16 mintChainId;
        /// @dev Used so a tokenID 0 can't wake the slumberParty before special Honeyjar is found.
        bool fermentedJarsFound;
        /// @dev used to track the number of used fermentedJars
        uint256 numUsed;
        /// @dev list of jars that have a claim on the sleeping NFTs
        FermentedJar[] fermentedJars;
        /// @dev list of sleeping NFTs
        SleepingNFT[] sleepoors;
    }

    /// @notice the struct that is signed with the domain separator to validate fermented jar ownership
    struct SignedMessage {
        address owner;
        uint8 bundleId;
        uint256 jarId;
    }

    /// @notice Configuration for minting for games occurring at the same time.
    struct MintConfig {
        /// @dev maximum number of honeyJar alloted to be minted.
        uint32 maxHoneyJar; // Max # of generated honeys (Max of 4.2m)
        /// @dev number of free honey jars to be claimed. Should be sum(gates.maxClaimable)
        uint32 maxClaimableHoneyJar; // # of honeyJars that can be claimed (total)
        /// @dev value of the honeyJar in ERC20 -- Ohm is 1e9
        uint256 honeyJarPrice_ERC20;
        /// @dev value of the honeyJar in ETH
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
    error FermentedJarNotFound(uint8 bundleId);
    error NotEnoughHoneyJarMinted(uint8 bundleId);
    error GeneralMintNotOpen(uint8 bundleId);
    error InvalidBundle(uint8 bundleId);
    error NotSleeping(uint8 bundleId);
    error TooManyBundles();

    // User Errors
    error NotFermentedJarOwner(uint8 bundleId, uint256 honeyJarId);
    error InvalidInput(string method);
    error Claim_InvalidProof();
    error MekingTooManyHoneyJars(uint8 bundleId);
    error ZeroMint();
    error WrongAmount_ETH(uint256 expected, uint256 actual);
    error NotJarOwner();
    error JarUsed(uint8 bundle, uint256 jarId);
    error InvalidChain(uint256 expectedChain, uint256 actualChain);

    /**
     * Events
     */
    event Initialized(MintConfig mintConfig);
    event PortalSet(address portal);
    event SlumberPartyStarted(uint8 bundleId);
    event SlumberPartyAdded(uint8 bundleId);
    event FermentedJarsFound(uint8 bundleId, uint256[] honeyJarIds);
    event MintConfigChanged(MintConfig mintConfig);
    event VRFConfigChanged(VRFConfig vrfConfig);
    event HoneyJarClaimed(uint256 bundleId, uint32 gateId, address player, uint256 amount);
    event SleeperAwoke(uint8 bundleId, uint256 tokenId, uint256 jarId, address player);
    event SleeperAdded(uint8 bundleId_, SleepingNFT sleeper);
    event CheckpointUpdated(uint256 index, bool isSet);

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
    IGatekeeper public immutable gatekeeper;
    IHoneyJar public immutable honeyJar;
    VRFCoordinatorV2Interface internal immutable vrfCoordinator;
    IHoneyJarPortal public honeyJarPortal;

    /**
     * Internal Storage
     */
    bool public initialized;

    /// @notice id of the next party
    /// @dev Required for storage pointers in next mapping
    SlumberParty[] public slumberPartyList;
    /// @notice bundleId --> SlumblerParty
    mapping(uint8 => SlumberParty) public slumberParties;
    /// @notice tracks free claims for a given bundle
    mapping(uint8 => uint32) public claimed;
    /// @notice Chainlink VRF request ID => bundleID
    mapping(uint256 => uint8) public rng;
    /// @notice Reverse mapping for honeyjar to bundle (UI)
    mapping(uint256 => uint8) public honeyJarToParty; // Reverse mapping for honeyJar to bundle (needed for UI)
    /// @notice list of HoneyJars associated with a particular SlumberParty (bundle)
    mapping(uint8 => uint256[]) public honeyJarShelf;
    /// @notice the winning checkpoints (generic for each game)
    BitMaps.BitMap private partyCheckpoints;

    constructor(
        address _vrfCoordinator,
        address _gameRegistry,
        address _honeyJarAddress,
        address _paymentToken,
        address _gatekeeper,
        address _jani,
        address _beekeeper,
        uint256 _honeyJarShare
    ) VRFConsumerBaseV2(_vrfCoordinator) GameRegistryConsumer(_gameRegistry) CrossChainTHJ() {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        honeyJar = IHoneyJar(_honeyJarAddress);
        paymentToken = IERC20(_paymentToken);
        gatekeeper = IGatekeeper(_gatekeeper);
        jani = payable(_jani);
        beekeeper = payable(_beekeeper);
        honeyJarShare = _honeyJarShare;
    }

    /// @notice additional parameters that are required to get the game running
    /// @param vrfConfig_ Chainlink  configuration
    /// @param mintConfig_ needed for the specific game
    function initialize(VRFConfig calldata vrfConfig_, MintConfig calldata mintConfig_)
        external
        onlyRole(Constants.GAME_ADMIN)
    {
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

    /// @notice view method to determine if JarNum results in a fermentation event
    function isCheckpoint(uint256 jarNum) external view returns (bool) {
        return partyCheckpoints.get(jarNum);
    }

    /// @notice Once a bundle is configured, transfers the configured assets into this contract.
    /// @notice Starts the gates within the Gatekeeper, which determine who is allowed early access and free claims
    /// @dev Bundles need to be preconfigured using addBundle from gameAdmin
    /// @dev publicMintTime is is configued to be the LAST item in the stageTimes from gameRegistry.
    function puffPuffPassOut(uint8 bundleId_) external onlyRole(Constants.GAME_ADMIN) {
        SlumberParty storage slumberParty = slumberParties[bundleId_]; // Will throw index out of bounds if not valid bundleId_
        SleepingNFT[] storage sleepoors = slumberParty.sleepoors;
        uint256 sleeperCount = sleepoors.length;
        if (sleeperCount == 0) revert InvalidBundle(bundleId_);

        uint256[] memory allStages = _getStages();
        uint256 publicMintOffset = allStages[allStages.length - 1];

        slumberParties[bundleId_].publicMintTime = block.timestamp + publicMintOffset;

        for (uint256 i = 0; i < sleeperCount; ++i) {
            _transferSleeper(sleepoors[i], msg.sender, address(this));
        }

        // Only start gates if the configured chainId is the current chain.
        if (slumberParty.mintChainId == getChainId()) {
            gatekeeper.startGatesForBundle(bundleId_);
        } else if (address(honeyJarPortal) != address(0)) {
            // If the portal is set, the xChain message will be sent
            honeyJarPortal.sendStartGame(slumberParty.mintChainId, bundleId_, sleeperCount);
        }
        emit SlumberPartyStarted(bundleId_);
    }

    /// @notice Does the same as function above, except doesn't transfer the NFTs.
    /// @notice is used on the destination chain in an xChain setup.
    /// @dev can only be called by the HoneyJar Portal
    function startGame(uint256 srcChainId, uint8 bundleId_, uint256 numSleepers_) external onlyRole(Constants.PORTAL) {
        uint256[] memory allStages = _getStages();
        uint256 publicMintOffset = allStages[allStages.length - 1];

        SlumberParty storage party = slumberParties[bundleId_];
        party.bundleId = bundleId_;
        party.assetChainId = SafeCastLib.safeCastTo16(srcChainId);
        party.mintChainId = getChainId(); // On the destination chain you MUST be able to mint.
        if (party.sleepoors.length != 0) revert InvalidBundle(bundleId_);

        party.publicMintTime = block.timestamp + publicMintOffset;
        // Push empty sleepers.
        SleepingNFT memory emptyNft;
        for (uint256 i = 0; i < numSleepers_; i++) {
            party.sleepoors.push(emptyNft);
        }
        gatekeeper.startGatesForBundle(bundleId_);

        emit SlumberPartyStarted(bundleId_);

        return;
    }

    /// @notice admin function to add more sleepers to the party once a bundle is started
    /// @param sleeper the NFT being added
    /// @param transfer to indicates if a transfer should be called. -- false: if an NFT is yeted in/airdroped
    function addToParty(uint8 bundleId_, SleepingNFT calldata sleeper, bool transfer)
        external
        onlyRole(Constants.GAME_ADMIN)
    {
        SlumberParty storage party = slumberParties[bundleId_];
        party.sleepoors.push(sleeper);

        if (transfer) {
            _transferSleeper(sleeper, msg.sender, address(this));
        }

        emit SleeperAdded(bundleId_, sleeper);
    }

    /// @notice method stores the configuration for the sleeping NFTs
    // bundleId --> bundle --> []nfts
    function addBundle(
        uint256 mintChainId_,
        address[] calldata tokenAddresses_,
        uint256[] calldata tokenIds_,
        bool[] calldata isERC1155_
    ) external onlyRole(Constants.GAME_ADMIN) returns (uint8) {
        uint256 inputLength = tokenAddresses_.length;
        if (inputLength == 0 || inputLength != tokenIds_.length || inputLength != isERC1155_.length) {
            revert InvalidInput("addBundle");
        }

        if (slumberPartyList.length > 255) revert TooManyBundles();
        uint8 bundleId = uint8(slumberPartyList.length);

        // Add to the bundle mapping & list
        SlumberParty storage slumberParty = slumberPartyList.push(); // 0 initialized Bundle
        slumberParty.bundleId = bundleId;
        slumberParty.assetChainId = getChainId(); // Assets will be on this chain.
        slumberParty.mintChainId = SafeCastLib.safeCastTo16(mintChainId_); // minting can occur on another chain

        // Synthesize sleeper configs from input
        for (uint256 i = 0; i < inputLength; ++i) {
            slumberParty.sleepoors.push(SleepingNFT(tokenAddresses_[i], tokenIds_[i], isERC1155_[i]));
        }

        slumberParties[bundleId] = slumberParty;

        emit SlumberPartyAdded(bundleId);
        return bundleId;
    }

    /// @dev internal helper function to perform conditional checks for minting state
    function _canMintHoneyJar(uint8 bundleId_, uint256 amount_) internal view {
        if (!initialized) revert NotInitialized();
        SlumberParty storage party = slumberParties[bundleId_];

        if (party.bundleId != bundleId_) revert InvalidBundle(bundleId_);
        if (party.mintChainId != getChainId()) revert InvalidChain(party.mintChainId, getChainId());
        if (party.publicMintTime == 0) revert NotSleeping(bundleId_);
        if (party.fermentedJarsFound) revert PartyAlreadyWoke(bundleId_); // Check if fermented jars found
        if (honeyJarShelf[bundleId_].length > mintConfig.maxHoneyJar) revert AlreadyTooManyHoneyJars(bundleId_);
        if (honeyJarShelf[bundleId_].length + amount_ > mintConfig.maxHoneyJar) {
            revert MekingTooManyHoneyJars(bundleId_);
        }
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

    function mekHoneyJarWithETH(uint8 bundleId_, uint256 amount_) external payable returns (uint256) {
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
        uint256 numMinted = honeyJarShelf[bundleId_].length;
        if (numMinted >= mintConfig.maxHoneyJar) {
            _fermentJars(bundleId_);
        } else if (partyCheckpoints.get(numMinted)) {
            // TODO: Doesn't work for batch mints.
            _fermentOneJar(bundleId_);
        }

        return tokenId - 1; // returns the lastID created
    }

    /// @notice Forcing function to find a winning HoneyJars. 1 for each item in the bundle
    /// @notice Should only be called when the last honeyJars is minted.
    function _fermentJars(uint8 bundleId_) internal {
        // account for already already winners.
        uint256 numSleepers = slumberParties[bundleId_].sleepoors.length;
        uint256 numFermented = slumberParties[bundleId_].fermentedJars.length;
        uint32 numWords = SafeCastLib.safeCastTo32(numSleepers - numFermented);
        uint256 requestId = vrfCoordinator.requestRandomWords(
            vrfConfig.keyHash, vrfConfig.subId, vrfConfig.minConfirmations, vrfConfig.callbackGasLimit, numWords
        );
        rng[requestId] = bundleId_;
    }

    /// @notice Fermine only one honejar for a given bundle
    /// @notice mainly used for checkpoint logic.
    function _fermentOneJar(uint8 bundleId_) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            vrfConfig.keyHash, vrfConfig.subId, vrfConfig.minConfirmations, vrfConfig.callbackGasLimit, 1
        );
        rng[requestId] = bundleId_;
    }

    /// @notice the callback method that is called when VRF completes
    /// @param requestId requestId that is generated when initially calling VRF
    /// @param randomness an array of random numbers based on `numWords` config
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        /// use requestID to get bundleId
        uint8 bundleId = rng[requestId];
        _setFermentedJars(bundleId, randomness);
    }

    /// @notice sets the winners of each NFT
    /// @param bundleId self-explanatory
    /// @param randomNumbers array of randomNumbers returned by chainlink VRF
    function _setFermentedJars(uint8 bundleId, uint256[] memory randomNumbers) internal {
        SlumberParty storage party = slumberParties[bundleId];
        uint256[] memory honeyJarIds = honeyJarShelf[bundleId];
        uint256 numHoneyJars = honeyJarShelf[bundleId].length;
        uint256 numFermentedJars = randomNumbers.length;
        uint256[] memory fermentedIndexes = new uint256[](numFermentedJars); // used for emitting the event

        uint256 fermentedIndex;
        for (uint256 i = 0; i < numFermentedJars; i++) {
            fermentedIndex = randomNumbers[i] % numHoneyJars;
            fermentedIndexes[i] = fermentedIndex;
            party.fermentedJars.push(FermentedJar(honeyJarIds[fermentedIndex], false));
        }
        party.fermentedJarsFound = true;

        // TODO: does this need to be in the VRF call?
        if (party.assetChainId != getChainId() && address(honeyJarPortal) != address(0)) {
            honeyJarPortal.sendFermentedJars(party.assetChainId, party.bundleId, honeyJarIds);
        }

        emit FermentedJarsFound(bundleId, fermentedIndexes);
    }

    /// @notice called by portal when the fermented jars are found on another chain
    /// @dev should only be called by PORTAL since this changes who is the winner
    function setCrossChainFermentedJars(uint8 bundleId, uint256[] calldata fermentedJarIds)
        external
        onlyRole(Constants.PORTAL)
    {
        if (fermentedJarIds.length == 0) revert InvalidInput("setCrossChainFermentedJars");
        SlumberParty storage party = slumberParties[bundleId];
        party.fermentedJarsFound = true;
        for (uint256 i = 0; i < fermentedJarIds.length; i++) {
            party.fermentedJars.push(FermentedJar(fermentedJarIds[i], false));
        }

        emit FermentedJarsFound(bundleId, fermentedJarIds);
    }

    /// @notice transfers sleeping NFT to msg.sender if they hold the special honeyJar
    /// @dev The index in which the jarId is stored within party.fermentedJars will be the index of the NFT that will be claimed for party.sleepoors
    function wakeSleeper(uint8 bundleId_, uint256 jarId) external nonReentrant {
        // Validate that the caller of the method holds the honeyjar
        if (honeyJar.ownerOf(jarId) != msg.sender) {
            revert NotJarOwner();
        }

        SlumberParty storage party = slumberParties[bundleId_];
        if (party.assetChainId == party.mintChainId) {
            // Only perform these validations if the asset and mint chainID are the same.
            if (honeyJarShelf[bundleId_].length < mintConfig.maxHoneyJar) revert NotEnoughHoneyJarMinted(bundleId_);
        }
        if (party.assetChainId != getChainId()) revert InvalidChain(party.assetChainId, getChainId()); // Can only claim on chains with the asset
        if (party.numUsed == party.sleepoors.length) revert PartyAlreadyWoke(bundleId_);
        if (!party.fermentedJarsFound) revert FermentedJarNotFound(bundleId_);

        FermentedJar[] storage fermentedJars = party.fermentedJars;

        uint256 numFermentedJars = fermentedJars.length;
        uint256 sleeperIndex = 0;
        for (uint256 i = 0; i < numFermentedJars; ++i) {
            if (fermentedJars[i].id != jarId) continue;
            if (fermentedJars[i].isUsed) revert JarUsed(bundleId_, jarId);
            // The caller is the owner of the Fermented jar and its unused
            fermentedJars[i].isUsed = true;
            sleeperIndex = party.numUsed; // Use the next available sleeper
            party.numUsed++;

            // party.numUsed is the index of the sleeper to wake up
            _transferSleeper(party.sleepoors[sleeperIndex], address(this), msg.sender);
            emit SleeperAwoke(bundleId_, party.sleepoors[i].tokenId, jarId, msg.sender);
            // Early return out of loop if successful
            return;
        }

        // If you complete the for loop without returning then you don't own the right NFT
        revert NotFermentedJarOwner(bundleId_, jarId);
    }

    /// @notice transfers NFT defined by sleeper_ to the caller of of the method
    function _transferSleeper(SleepingNFT memory sleeper_, address from, address to) internal {
        if (sleeper_.isERC1155) {
            // ERC1155
            IERC1155(sleeper_.tokenAddress).safeTransferFrom(from, to, sleeper_.tokenId, 1, "");
        } else {
            //  ERC721
            IERC721(sleeper_.tokenAddress).safeTransferFrom(from, to, sleeper_.tokenId);
        }
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
    function claim(uint8 bundleId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) public nonReentrant {
        // Gatekeeper tracks per-player/per-gate claims
        if (proof.length == 0) revert Claim_InvalidProof();
        uint32 numClaim = gatekeeper.calculateClaimable(bundleId_, gateId, msg.sender, amount, proof);
        if (numClaim == 0) {
            return;
        }

        // Track per bear freeClaims
        uint32 claimedAmount = claimed[bundleId_];
        if (numClaim + claimedAmount > mintConfig.maxClaimableHoneyJar) {
            numClaim = mintConfig.maxClaimableHoneyJar - claimedAmount;
        }
        // Check if the HoneyJars can be minted
        _canMintHoneyJar(bundleId_, numClaim); // Validating here because numClaims can change

        // Update the amount minted.
        claimed[bundleId_] += numClaim;

        // Can be combined with "claim" call above, but keeping separate to separate view + modification on gatekeeper
        gatekeeper.addClaimed(bundleId_, gateId, numClaim, proof);

        // If for some reason this fails, GG no honeyJar for you
        _mintHoneyJarForBear(msg.sender, bundleId_, numClaim);

        emit HoneyJarClaimed(bundleId_, gateId, msg.sender, numClaim);
    }

    /// @dev Helper function to process all free cams. More client-sided computation.
    /// @param bundleId_ the bundle to claim tokens for.
    /// @param gateIds the list of gates to claim. The txn will revert if an ID for an inactive gate is included.
    /// @param amounts the list of amounts being claimed for the repsective gates.
    /// @param proofs the list of proofs associated with the respective gates
    function claimAll(
        uint8 bundleId_,
        uint32[] calldata gateIds,
        uint32[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        uint256 inputLength = proofs.length;
        if (inputLength != gateIds.length) revert InvalidInput("claimAll");
        if (inputLength != amounts.length) revert InvalidInput("claimAll");

        for (uint256 i = 0; i < inputLength; ++i) {
            claim(bundleId_, gateIds[i], amounts[i], proofs[i]);
        }
    }

    //=============== SETTERS ================//

    /// @notice sets HoneyJarPortal which is responsible for xChain communication.
    function setPortal(address portal_) external onlyRole(Constants.GAME_ADMIN) {
        honeyJarPortal = IHoneyJarPortal(portal_);

        emit PortalSet(portal_);
    }

    /**
     * Game setters
     *  These should not be called while a game is in progress to prevent hostage holding.
     */

    /// @notice Sets the max number NFTs (honeyJar) that can be generated from the deposit of a bear (asset)
    function setMaxHoneyJar(uint32 _maxhoneyJar) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.maxHoneyJar = _maxhoneyJar;

        emit MintConfigChanged(mintConfig);
    }

    /// @notice sets the number of global free claims available
    function setMaxClaimableHoneyJar(uint32 _maxClaimableHoneyJar) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.maxClaimableHoneyJar = _maxClaimableHoneyJar;

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

    /// @notice checkpoints where there can be one winner.
    /// @param checkpoints_ the JarNumber that determins winners.
    function setCheckpoints(uint256[] calldata checkpoints_) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();

        for (uint256 i = 0; i < checkpoints_.length; ++i) {
            partyCheckpoints.set(checkpoints_[i]);
            emit CheckpointUpdated(checkpoints_[i], true);
        }
    }

    /// @notice reset the previously configured checkpoints.
    /// @param checkpoints_ the JarNumbers that have previously been configured as winning checkpoints.
    function unsetCheckpoints(uint256[] calldata checkpoints_) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();

        for (uint256 i = 0; i < checkpoints_.length; ++i) {
            partyCheckpoints.unset(checkpoints_[i]);
            emit CheckpointUpdated(checkpoints_[i], false);
        }
    }

    /**
     * Chainlink Setters
     */

    /// @notice Set from the following docs: https://docs.chain.link/docs/vrf-contracts/#configurations
    function setVRFConfig(VRFConfig calldata vrfConfig_) external onlyRole(Constants.GAME_ADMIN) {
        vrfConfig = vrfConfig_;
        emit VRFConfigChanged(vrfConfig_);
    }
}
