// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {THJScriptBase} from "./THJScriptBase.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HoneyBox} from "src/HoneyBox.sol";
import {Constants} from "src/Constants.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeployScript is THJScriptBase {
    // Goerli deps
    address private VRF_COORDINATOR = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 private VRF_KEYHASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // Already deployed:
    // address private gameRegistry = 0x4208befD8f546282aB43A30085774513227B656C;
    // address private honeyjar = 0x1DeB9157508316A24BC0527444B142f563705BD0;
    // address private erc1155 = 0x21FDb00713C74147c2BB629De13531Ab51a94b8B;
    // address private paymentToken = 0x2F69c44dc3cb7C6508e49AD374BdfA332EB11416;

    // External Addresses
    address gameAdmin = 0xd4920Bb5A6C032eB3BcE21E0C7FdAC9EeFa8d3f1;

    // Config
    uint256 private honeyJarShare = 2233 * 1e14;
    bytes32 private keyhash = "";
    uint64 private subId = 9;
    uint256 private honeyJarStartIndex = 0;
    uint256 private honeyJarAmount = 69;

    HoneyBox.MintConfig private mintConfig;
    HoneyBox.VRFConfig private vrfConfig;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        MockERC1155 erc1155 = new MockERC1155();
        MockERC721 erc721 = new MockERC721("FekNFT", "FNFT");

        erc721.mint(gameAdmin, 0);
        erc721.mint(gameAdmin, 1);
        erc721.mint(gameAdmin, 2);

        erc1155.mint(gameAdmin, 0, 1, "");
        erc1155.mint(gameAdmin, 1, 1, "");
        erc1155.mint(gameAdmin, 2, 1, "");

        MockERC20 paymentToken = new MockERC20("OHM", "OHM", 9);
        paymentToken.mint(gameAdmin, 99 * 1e8 * 100);

        GameRegistry gameRegistry = new GameRegistry();
        gameRegistry.grantRole(Constants.GAME_ADMIN, gameAdmin);

        Gatekeeper gatekeeper = new Gatekeeper(address(gameRegistry));
        HoneyJar honeyJar = new HoneyJar(address(gameRegistry), honeyJarStartIndex, honeyJarAmount);

        HoneyBox honeyBox = new HoneyBox(
            address(VRF_COORDINATOR),
            address(gameRegistry),
            address(honeyJar),
            address(paymentToken),
            address(gatekeeper),
            address(this),
            address(this),
            honeyJarShare
        );

        /**
         * Setup
         */

        mintConfig = HoneyBox.MintConfig({
            maxHoneyJar: 69,
            maxClaimableHoneyJar: 4,
            honeyJarPrice_ERC20: 99 * 1e8, // 9.9 OHM
            honeyJarPrice_ETH: 99 * 1e6 * 1 gwei // 0.099 eth
        });

        honeyBox.initialize(HoneyBox.VRFConfig(VRF_KEYHASH, subId, 3, 10000000), mintConfig);

        // Register game with gameRegistry
        gameRegistry.registerGame(address(honeyBox));

        vm.stopBroadcast();
    }
}
