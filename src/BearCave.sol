// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/ReentrancyGuard.sol";

import "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";

import {Gatekeeper} from "./Gatekeeper.sol";
import {IHoneyComb} from "./IHoneyComb.sol";
import {IBearCave} from "./IBearCave.sol";
import {GameRegistryConsumer} from "./GameRegistry.sol";
import {Constants} from "./GameLib.sol";

// Example: https://opensea.io/0xd87fa9FeD90948cd7deA9f77c06b9168Ac07F407 :dafoe:
contract BearCave is IBearCave, VRFConsumerBaseV2, ERC1155TokenReceiver, ReentrancyGuard, GameRegistryConsumer {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /**
     *  Game Errors
     */
    // Contract State
    error NotInitialized();
    error AlreadyInitialized();
    // Game state
    error BearAlreadyWoke(uint256 bearId);
    error GameInProgress();
    error TooManyHoneyCombs(uint256 bearId);
    error SpecialHoneyCombNotFound(uint256 bearId);
    error NotEnoughHoneyCombMinted(uint256 bearId);

    // User Errors
    error NotOwnerOfSpecialHoneyComb(uint256 bearId, uint256 honeycombId);
    error Claim_IncorrectInput();
    error Claim_InvalidProof();

    /**
     * Configuration
     */
    ERC20 public paymentToken; // OHM
    ERC1155 private erc1155; //the openseaAddress (rip) for Bears
    MintConfig private mintConfig;
    bool private distributeWithMint; // Feature Toggle... what if we just make a feature toggle lib...

    /**
     * Chainlink VRF Config
     */
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 internal keyHash; // TODO: config VRF
    uint64 internal subId = 69; // TODO: https://vrf.chain.link/goerli/new
    uint16 internal minConfirmations = 3; // Default is 3

    // Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract.
    uint32 internal callbackGasLimit = 100000; // enough for ~5 words

    /**
     * bearPouch
     */
    address payable private beekeeper; // rev share 22.33%
    address payable private jani;
    uint256 private honeyCombShare; // as a WAD
    // Accounting vars
    uint256 public totalFees;
    uint256 private totalERC20Fees;
    uint256 private totalETHfees;

    /**
     * Depenedncies
     */
    Gatekeeper public gatekeeper;
    IHoneyComb public honeycomb;
    VRFCoordinatorV2Interface internal vrfCoordinator;

    /**
     * Internal Storage
     */
    bool initialized;
    // TODO: Review usage & combine these mappings into a single struct where appropriate.
    mapping(uint256 => HibernatingBear) public bears; //  bearId --> hibernatingBear status
    mapping(uint256 => uint256[]) public honeyJar; //  bearId --> honeycomb that was made for it (honeyJar[bearId].length is # minted honeycomb)
    mapping(uint256 => uint256) public honeycombToBear; // Reverse mapping: honeyId -> bearId
    mapping(uint256 => uint32) public claimed; // bearid -> numClaimed
    mapping(uint256 => uint256) public rng; // Chainlink VRF request ID => bearId

    constructor(
        address _vrfCoordinator,
        address _gameRegistry,
        address _honeycombAddress,
        address _erc1155Address,
        address _paymentToken,
        address _gatekeeper,
        uint256 _honeyCombShare
    ) VRFConsumerBaseV2(_vrfCoordinator) GameRegistryConsumer(_gameRegistry) ReentrancyGuard() {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        honeycomb = IHoneyComb(_honeycombAddress);
        erc1155 = ERC1155(_erc1155Address);
        paymentToken = ERC20(_paymentToken);
        gatekeeper = Gatekeeper(_gatekeeper);
        honeyCombShare = _honeyCombShare;
    }

    function initialize(MintConfig calldata mintConfig_) external onlyRole(Constants.GAME_ADMIN) {
        if (initialized) revert AlreadyInitialized();

        initialized = true;
        mintConfig = mintConfig_;
    }

    /// @notice you miss your bear so you want it
    function getBear(uint256 _bearId) external view returns (HibernatingBear memory) {
        return bears[_bearId];
    }

    /// @inheritdoc IBearCave
    function hibernateBear(uint256 _bearId) external onlyRole(Constants.GAME_ADMIN) {
        // This is shitty, because theres only one permissions thing.
        require(erc1155.isApprovedForAll(msg.sender, address(this)), "Gibb cave to permissions to hibernate your bear");

        erc1155.safeTransferFrom(msg.sender, address(this), _bearId, 1, "");

        bears[_bearId] = HibernatingBear(_bearId, 0, false, false);
    }

    function _canMintHoneycomb(uint256 bearId_) internal view {
        if (!initialized) revert NotInitialized();
        HibernatingBear memory bear = bears[bearId_];

        require(bear.id == bearId_, "Da bear isn't hibernating");
        if (bear.isAwake) revert BearAlreadyWoke(bearId_);
        if (honeyJar[bearId_].length > mintConfig.maxHoneycomb) revert TooManyHoneyCombs(bearId_);
    }

    // TODO: earlyMint
    function earlyMint(uint256 bearId, uint32 gateId, uint32 amount, bytes32[] calldata proof) external {}

    /// @inheritdoc IBearCave
    function mekHoneyCombWithERC20(uint256 bearId_) external returns (uint256) {
        _canMintHoneycomb(bearId_);
        uint256 price = mintConfig.honeycombPrice_ERC20;

        if (distributeWithMint) {
            _distribute(price);
        } else {
            paymentToken.safeTransferFrom(msg.sender, address(this), price); // will revert if there isn't enough
            totalERC20Fees += price;
        }

        // Mint da honey
        return _mintHoneyCombForBear(msg.sender, bearId_);
    }

    function mekHoneyCombWithEth(uint256 bearId_) external payable returns (uint256) {
        _canMintHoneycomb(bearId_);
        uint256 price = mintConfig.honeycombPrice_ETH;

        require(msg.value == price, "MekHoney::Moar eth pls");

        if (distributeWithMint) {
            _distribute(0);
        } else {
            totalETHfees += price;
        }

        return _mintHoneyCombForBear(msg.sender, bearId_);
    }

    /// @notice internal method to mint for a particular user
    /// @param to user to mint to
    /// @param _bearId the bea being minted for
    function _mintHoneyCombForBear(address to, uint256 _bearId) internal returns (uint256) {
        uint256 tokenId = honeycomb.mint(to);

        // Have a unique tokenId for a given bearId
        honeyJar[_bearId].push(tokenId);
        honeycombToBear[tokenId] = _bearId;

        // Find the special honeycomb when the last honeyComb is minted.
        if (honeyJar[_bearId].length >= mintConfig.maxHoneycomb) {
            _findHoneyComb(_bearId);
        }

        return tokenId;
    }

    /// @notice this function _should_ only be called in case of emergencies
    /// @notice if the honeycombs are minted but the VRF called failed.
    /// @dev kicks off another VRF request
    function forceHoneycombSearch(uint256 bearId_) external onlyRole(Constants.GAME_ADMIN) {
        if (honeyJar[bearId_].length < mintConfig.maxHoneycomb) revert NotEnoughHoneyCombMinted(bearId_);
        _findHoneyComb(bearId_);
    }

    /// @notice Forcing function to find a bear.
    /// @notice Should only be called when the last honeyCombs is minted.
    function _findHoneyComb(uint256 bearId_) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(keyHash, subId, minConfirmations, callbackGasLimit, 2);
        rng[requestId] = bearId_;
    }

    /// @notice the callback method that is called when VRF completes
    /// @param requestId requestId that is generated when initiaully calling VRF
    /// @param randomness an array of random numbers based on `numWords` config
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        /// use requestID to get bearId
        uint256 bearId = rng[requestId];
        _setSpecialHoneyComb(bearId, randomness[0]);
    }

    /// @notice helper function to set a random honeycomb as a winner
    /// @param bearId self-explanatpry
    /// @param randomNumber used to determine the index of the winnign number
    function _setSpecialHoneyComb(uint256 bearId, uint256 randomNumber) internal {
        uint256 numHoneyCombs = honeyJar[bearId].length;
        uint256 specialHoneyIndex = randomNumber % numHoneyCombs;
        uint256 specialHoneyCombId = honeyJar[bearId][specialHoneyIndex];

        HibernatingBear storage bear = bears[bearId];
        bear.specialHoneycombFound = true;
        bear.specialHoneycombId = specialHoneyCombId;
    }

    /// @inheritdoc IBearCave
    /// @dev erc1155.safeTransferFrom is requires a reciever.
    function wakeBear(uint256 _bearId) external {
        // Check that msg.sender has the special honeycomb to wake up bear
        HibernatingBear memory bear = bears[_bearId];

        if (bear.isAwake) revert BearAlreadyWoke(_bearId);
        if (honeyJar[_bearId].length < mintConfig.maxHoneycomb) revert NotEnoughHoneyCombMinted(_bearId);
        if (!bear.specialHoneycombFound) revert SpecialHoneyCombNotFound(_bearId);

        if (honeycomb.ownerOf(bear.specialHoneycombId) != msg.sender)
            revert NotOwnerOfSpecialHoneyComb(_bearId, bear.specialHoneycombId);

        // Send over bear
        erc1155.safeTransferFrom(address(this), msg.sender, bear.id, 1, "");
    }

    /**
     * BearPouch owner methods
     *      Can move into another contract for portability
     * depends on:
     *     Exclusive: beekeeper, jani, honeyCombShare
     *     shared: paymentToken
     */

    /// @dev requires that beekeeper and jani addresses are set.
    /// @param amountERC20 is zero if we're only distributing the ETH
    function _distribute(uint256 amountERC20) internal {
        uint256 beekeeperShareERC20 = amountERC20.mulWadUp(honeyCombShare);
        uint256 beekeeperShareETH = (msg.value).mulWadUp(honeyCombShare);

        if (beekeeperShareERC20 > 0) {
            paymentToken.safeTransferFrom(msg.sender, beekeeper, beekeeperShareERC20);
            paymentToken.safeTransferFrom(msg.sender, jani, amountERC20 - beekeeperShareERC20);
        }

        if (beekeeperShareETH > 0) {
            SafeTransferLib.safeTransferETH(beekeeper, beekeeperShareETH);
            SafeTransferLib.safeTransferETH(jani, msg.value - beekeeperShareETH);
        }
    }

    function _splitFee(uint256 currentBalance) internal view returns (uint256) {
        return currentBalance.mulWadUp(honeyCombShare);
    }

    /// @notice should only get called in the event automatic distribution doesn't work
    function withdrawERC20() external nonReentrant returns (uint256) {
        require(!distributeWithMint, "distriboot w/ mints should be false");
        // permissions check
        require(_hasRole(Constants.JANI) || _hasRole(Constants.BEEKEEPER), "oogabooga you can't do that");
        require(beekeeper != address(0), "withdrawFunds::beekeeper address not set");
        require(jani != address(0), "withdrawFunds::jani address not set");

        uint256 currBalance = paymentToken.balanceOf(address(this));
        require(currBalance > 0, "oogabooga theres nothing here");

        // xfer everything all at once so we don't have to worry about accounting
        uint256 beekeeperShare = _splitFee(currBalance);
        paymentToken.safeTransfer(beekeeper, beekeeperShare);
        paymentToken.safeTransfer(jani, paymentToken.balanceOf(address(this))); // This should be everything

        return paymentToken.balanceOf(address(this));
    }

    /// @notice should only get called in the event automatic distribution doesn't work
    function withdrawETH() public nonReentrant returns (uint256) {
        require(!distributeWithMint, "distriboot w/ mints should be false");
        require(_hasRole(Constants.JANI) || _hasRole(Constants.BEEKEEPER), "oogabooga you can't do that");
        require(beekeeper != address(0), "withdrawETH::beekeeper address not set");
        require(jani != address(0), "withdrawFunds::jani address not set");

        uint256 beekeeperShare = _splitFee(address(this).balance);
        SafeTransferLib.safeTransferETH(beekeeper, beekeeperShare);
        SafeTransferLib.safeTransferETH(jani, address(this).balance);

        return address(this).balance;
    }

    /**
     * Gatekeeper: for claiming free honeycomb
     * BearCave:
     *    - maxMintableHoneyComb per Bear
     *    - claimedHoneyComb per Bear // free
     *    - maxClaimableHoneyComb per Bear
     * Gatekeeper: (per bear)
     * Gates:
     *    - maxHoneycombAvailable per gate
     *    - maxClaimable per gate
     * x
     */
    function claim(uint256 bearId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) public {
        _canMintHoneycomb(bearId_);
        // Gatekeeper tracks per-player/per-gate claims
        if (proof.length == 0) revert Claim_InvalidProof();
        uint32 numClaim = gatekeeper.claim(bearId_, gateId, msg.sender, amount, proof);
        if (numClaim == 0) {
            return;
        }

        // Track per bear freeClaims
        uint32 claimedAmount = claimed[bearId_];
        if (numClaim + claimedAmount > mintConfig.maxClaimableHoneycomb) {
            numClaim = mintConfig.maxClaimableHoneycomb - claimedAmount;
        }

        claimed[bearId_] += numClaim;

        // If for some reason this fails, GG no honeyComb for you
        for (uint256 i = 0; i < numClaim; ++i) {
            _mintHoneyCombForBear(msg.sender, bearId_);
        }
        // Can be combined with "claim" call above, but keeping separate to separate view + modification on gatekeeper
        gatekeeper.addClaimed(bearId_, gateId, numClaim, proof);
    }

    // Helpfer function to claim all the free shit
    function claimAll(
        uint256 bearId_,
        uint32[] calldata gateId,
        uint32[] calldata amount,
        bytes32[][] calldata proof
    ) external {
        uint256 inputLength = proof.length;
        if (inputLength != gateId.length) revert Claim_IncorrectInput();
        if (inputLength != amount.length) revert Claim_IncorrectInput();

        for (uint256 i = 0; i < inputLength; ++i) {
            if (proof[i].length == 0) continue; // Don't nomad yourself
            claim(bearId_, gateId[i], amount[i], proof[i]);
        }
    }

    //=============== SETTERS ================//

    /**
     * Bear Pouch setters (needed for distribution)
     *  Currently separate from the permissioned roles in gameRegistry
     */
    function setJani(address jani_) external onlyRole(Constants.GAME_ADMIN) {
        jani = payable(jani_);
    }

    function setBeeKeeper(address beekeeper_) external onlyRole(Constants.GAME_ADMIN) {
        beekeeper = payable(beekeeper_);
    }

    function setDisitrbuteWithMint(bool distributeWithMint_) external onlyRole(Constants.GAME_ADMIN) {
        distributeWithMint = distributeWithMint_;
    }

    /**
     * Game setters
     *  These should not be called while a game is in progress to prevent hostage holding.
     */

    /// @notice Sets the max number NFTs (honeyComb) that can be generated from the deposit of a bear (asset)
    function setMaxHoneycomb(uint32 _maxHoneycomb) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.maxHoneycomb = _maxHoneycomb;
    }

    /// @notice sets the price of the honeycomb in `paymentToken`
    function setHoneyCombPrice_ERC20(uint256 _honeyCombPrice) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.honeycombPrice_ERC20 = _honeyCombPrice;
    }

    /// @notice sets the price of the honeycomb in `ETH`
    function setHoneyCombPrice_ETH(uint256 _honeyCombPrice) external onlyRole(Constants.GAME_ADMIN) {
        if (_isEnabled(address(this))) revert GameInProgress();
        mintConfig.honeycombPrice_ETH = _honeyCombPrice;
    }

    /**
     * Chainlink Setters
     */
    function setSubId(uint64 subId_) external onlyRole(Constants.GAME_ADMIN) {
        subId = subId_;
    }
}
