// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import "solmate/tokens/ERC721.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/LibString.sol";

import "@chainlink/interfaces/LinkTokenInterface.sol";
import "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {Gatekeeper} from "./Gatekeeper.sol";
import {IHoneyComb} from "./IHoneyComb.sol";
import {IBearCave} from "./IBearCave.sol";

// Example: https://opensea.io/0xd87fa9FeD90948cd7deA9f77c06b9168Ac07F407 :dafoe:
contract BearCave is IBearCave, VRFConsumerBaseV2, ERC1155TokenReceiver, Owned {
    using LibString for uint256;
    using Counters for Counters.Counter;

    //address public openeaStoreToken = 0x495f947276749Ce646f68AC8c248420045cb7b5e;

    /**
     * Configuration
     */
    ERC20 public paymentToken; // OHM
    ERC1155 private erc1155; //the openseaAddress (rip) for Bears
    uint32 public maxHoneycomb; // Max # of generated honeys (Max of 4.2m -- we'll have 10420)
    uint8 public paymentTokenDecimals; // should be 9 for ohms
    uint32 public maxClaimableHoneyComb; // # of honeycombs that can be claimed for each game.
    uint32 public maxClaimableHoneyCombPerPlayer; // # of honeycombs that can be claimed for each game.
    uint256 public honeycombPrice;

    /**
     * Chainlink VRF Config
     */
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 internal keyHash; // TODO:
    uint16 internal minConfirmations = 3; // Default is 3
    uint64 internal subId = 69; // TODO: https://vrf.chain.link/goerli/new

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 internal callbackGasLimit = 100000; // enough for ~5 words

    /**
     * bearPouch config
     */
    address private beeKeeper; // rev share 22.33%
    address private jani;
    uint16 private honeyCombShare; // in bps (10_000)

    /**
     * Depenedncies
     */
    Gatekeeper public gatekeeper;
    IHoneyComb public honeycomb;
    VRFCoordinatorV2Interface internal vrfCoordinator;

    /**
     * Internal Storage
     */
    uint256 public totalFees; // Purely a view function
    Counters.Counter private lastHoneyId; // atomically increasing tokenId
    mapping(uint256 => HibernatingBear) public bears; //  bearId --> hibernatingBear status
    mapping(uint256 => uint256[]) public honeyJar; //  bearId --> honeycomb that was made for it
    mapping(uint256 => uint256) public honeycombToBear; // Reverse mapping: honeyId -> bearId
    mapping(uint256 => uint32) public claimed; // bearid -> numClaimed
    mapping(uint256 => uint256) public rng; // Chainlink VRF request ID => bearId

    constructor(
        address _vrfCoordinator,
        address _erc1155Address,
        address _paymentToken,
        address _honeycombAddress,
        uint256 _honeyCombPrice, // Based in the token
        uint32 _maxHoneycomb,
        uint16 _honeyCombShare
    ) VRFConsumerBaseV2(_vrfCoordinator) Owned(msg.sender) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        erc1155 = ERC1155(_erc1155Address);
        honeycomb = IHoneyComb(_honeycombAddress);
        paymentToken = ERC20(_paymentToken);
        paymentTokenDecimals = paymentToken.decimals();
        maxHoneycomb = _maxHoneycomb;
        honeycombPrice = _honeyCombPrice;
        honeyCombShare = _honeyCombShare;
    }

    function getBear(uint256 _bearId) external view returns (HibernatingBear memory) {
        return bears[_bearId];
    }

    // Accepts an ERC1155 token and transfers it to the contract
    function hibernateBear(uint256 _bearId) external onlyOwner {
        // This is shitty, because theres only one permissions thing.
        require(erc1155.isApprovedForAll(msg.sender, address(this)), "Gibb cave to permissions to hibernate your bear");

        erc1155.safeTransferFrom(msg.sender, address(this), _bearId, 1, "");

        bears[_bearId] = HibernatingBear(_bearId, 0, false, false);
    }

    // Makes honeycomb for the bear
    function mekHoneyComb(uint256 _bearId) external returns (uint256) {
        HibernatingBear memory bear = bears[_bearId];

        require(bear.id == _bearId, "Da bear isn't hibernating");
        require(!bear.isAwake, "Bear left the cave, y u try to make honeyComb");
        require(honeyJar[_bearId].length < maxHoneycomb, "Already made too much honeyCombs");

        // TODO: add an earlyAccessCheck
        totalFees += honeycombPrice;
        paymentToken.transferFrom(msg.sender, address(this), honeycombPrice);

        // Mint da honey
        return _mintHoneyCombForBear(msg.sender, _bearId);
    }

    function omgBees() external pure returns (bytes32) {
        return "omgBees";
    }

    function _mintHoneyCombForBear(address to, uint256 _bearId) internal returns (uint256) {
        uint256 tokenId = honeycomb.mint(to);

        // Have a unique tokenId for a given bearId
        honeyJar[_bearId].push(tokenId);
        honeycombToBear[tokenId] = _bearId;

        // Find the special honeycomb when the last honeyComb is minted.
        if (honeyJar[_bearId].length >= maxHoneycomb) {
            _findHoneyComb(_bearId);
        }

        return tokenId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        /// use requestID to get bearId
        uint256 bearId = rng[requestId];
        _setSpecialHoneyComb(bearId, randomness[0]);
    }

    function _setSpecialHoneyComb(uint256 bearId, uint256 randomNumber) internal {
        uint256 numHoneyCombs = honeyJar[bearId].length;
        uint256 specialHoneyIndex = randomNumber % numHoneyCombs;
        uint256 specialHoneyCombId = honeyJar[bearId][specialHoneyIndex];

        HibernatingBear storage bear = bears[bearId];
        bear.specialHoneycombFound = true;
        bear.specialHoneycombId = specialHoneyCombId;
    }

    // Forcing function to find a bear. Should only be called when the last honeyCombs is minted.
    function _findHoneyComb(uint256 bearId_) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(keyHash, subId, minConfirmations, callbackGasLimit, 2);
        rng[requestId] = bearId_;
    }

    /// @dev erc1155.safeTransferFrom is requires a reciever.
    function wakeBear(uint256 _bearId) external {
        // Check that msg.sender has the special honeycomb to wake up bear
        HibernatingBear memory bear = bears[_bearId];

        require(bear.isAwake == false, "wakeBear::Bear is already awake. Wut u do?");
        require(honeyJar[_bearId].length >= maxHoneycomb, "dafuq, there isn't enuff honeycombs yet");
        require(bear.specialHoneycombFound == true, "wakeBear::Look for special honeycomb pls"); // redundant check
        require(
            honeycomb.ownerOf(bear.specialHoneycombId) == msg.sender, "wakeBear::You don't have the special honeycomb"
        );

        // Send over bear
        erc1155.safeTransferFrom(address(this), msg.sender, bear.id, 1, "");
    }
    /**
     * Bear PouchSetters
     */

    function setJani(address jani_) external onlyOwner {
        jani = jani_;
    }

    function setBeeKeeper(address beeKeeper_) external onlyOwner {
        beeKeeper = beeKeeper_;
    }

    /**
     * Game setters
     */
    // Sets the max number NFTs (honeyComb) that can be generated from the deposit of a bear (asset)
    function setMaxHoneycomb(uint32 _maxHoneycomb) external onlyOwner {
        maxHoneycomb = _maxHoneycomb;
    }

    function setHoneyCombPrice(uint256 _honeyCombPrice) external onlyOwner {
        honeycombPrice = _honeyCombPrice;
    }

    /// @notice this function _should_ only be called in case of emergencies
    /// @notice if the honeycombs are minted but the VRF called failed.
    function forceHoneycombSearch(uint256 bearId_) external onlyOwner {
        _findHoneyComb(bearId_);
    }

    /**
     * Chainlink Setters
     */

    function setSubId(uint64 subId_) external onlyOwner {
        subId = subId_;
    }

    /**
     * BearPouch owner methods
     * Can move into another contract for portability
     * depends on:
     *     Exclusive: beekeeper, jani, honeyCombShare, paymentToken
     *     shared: paymentToken
     */
    function withdrawFunds() external returns (uint256) {
        // permissions check
        require(msg.sender == jani || msg.sender == beeKeeper, "oogabooga you can't do that");

        uint256 currBalance = paymentToken.balanceOf(address(this));
        require(currBalance > 0, "oogabooga theres nothing here");

        // xfer everything all at once so we don't have to worry about accounting
        paymentToken.transfer(beeKeeper, currBalance * honeyCombShare / 10_000);
        paymentToken.transfer(jani, (currBalance * (10_000 - honeyCombShare)) / 10_000); // This should be everything

        return paymentToken.balanceOf(address(this));
    }

    /**
     * Gatekeeper: for claiming free honeycomb
     * BearCave:
     *    - maxMintableHoneyComb per Bear
     *    - claimedHoneyComb per Bear// free
     * Gatekeeper: (per bear)
     *    - maxHoneycombAvailable per player
     * Gates:
     *    - maxHoneycombAvailable per gate
     *    - maxClaimable per gate
     * x
     */
    function claim(uint256 bearId_, uint32 gateId, uint32 amount, bytes32[] calldata proof) public {
        HibernatingBear memory bear = bears[bearId_];
        require(bear.id == bearId_, "Da bear isn't hibernating");
        require(!bear.isAwake, "bear is already awake");
        require(claimed[bearId_] < maxHoneycomb, "Already made too much honey");
        require(claimed[bearId_] < maxClaimableHoneyComb, "no more free honeycomb 4 u. GG");

        // Gatekeeper tracks per-player/per-gate claims
        uint32 numClaim = gatekeeper.claim(bearId_, gateId, msg.sender, amount, proof);
        if (numClaim == 0) {
            return;
        }

        // Track per bear freeClaims
        uint32 claimedAmount = claimed[bearId_];
        if (numClaim + claimedAmount > maxClaimableHoneyComb) {
            numClaim = maxClaimableHoneyComb - claimedAmount;
        }

        if (numClaim > maxClaimableHoneyCombPerPlayer) {
            numClaim = maxClaimableHoneyComb;
        }

        claimed[bearId_] += numClaim;

        // If for some reason this fails, GG no honeyComb for you
        for (uint256 i = 0; i < numClaim; ++i) {
            _mintHoneyCombForBear(msg.sender, bearId_);
        }
        // Can be combined with "claim" call above, but keeping separate to separate view + modification on gatekeeper
        gatekeeper.addClaimed(bearId_, gateId, msg.sender, numClaim);
    }

    // Helpfer function to claim all the free shit
    function claimAll(uint256 bearId_, uint32[] calldata gateId, uint32[] calldata amount, bytes32[][] calldata proof)
        external
    {
        uint256 inputLength = proof.length;
        require(inputLength == gateId.length, "claimAll:incorrectInput");
        require(inputLength == amount.length, "claimAll:incorrectInput");

        for (uint256 i = 0; i < inputLength; ++i) {
            claim(bearId_, gateId[i], amount[i], proof[i]);
        }
    }
}
