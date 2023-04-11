// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {HoneyJar} from "src/HoneyJar.sol";
import {GameRegistry} from "src/GameRegistry.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";
import {HoneyBox} from "src/HoneyBox.sol";
import {Constants} from "src/Constants.sol";

import {MockERC1155} from "test/mocks/MockERC1155.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract BundleTokens is Script {
    // Already deployed:
    address private gameRegistry = 0x1AA2A723994ADbF749fA39aa307460c121c4d615;
    address private honeyjar = 0x447FDff9e8a9b43A50b9F3cEB36413407bC8Ed4d;
    address private erc1155 = 0x098D39bf9D50f2504ACF7B201B4f2e9169A1b388;
    address private erc721 = 0xeC420B0d0dA852359e0D6a31Ec322AB502C788a2;
    address private paymentToken = 0xcbD331954e0f7184AE8fCbFb93D87ddc3cB171B4;
    address private gatekeeper = 0xd4aBC6798AA37F938023D228cc9eb57393bF4dEE;
    address private honeybox = 0x03B06Fd882B8693a9D6D2FC3c211f73d62448041;

    uint256 private SFT_ID = 1;
    uint256 private NFT_ID = 1;

    // uint8 private bundleId = 0;

    // External Addresses
    address gameAdmin = 0xd4920Bb5A6C032eB3BcE21E0C7FdAC9EeFa8d3f1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Gatekeeper gk = Gatekeeper(gatekeeper);
        HoneyJar hj = HoneyJar(honeyjar);
        HoneyBox hb = HoneyBox(honeybox);
        GameRegistry gr = GameRegistry(gameRegistry);
        MockERC721 nft = MockERC721(erc721);
        MockERC1155 sft = MockERC1155(erc1155);

        /**
         * Setup
         */

        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(erc721);
        tokenAddresses[1] = address(erc1155);

        uint256[] memory tokenIDs = new uint256[](2);
        tokenIDs[0] = NFT_ID;
        tokenIDs[1] = SFT_ID;

        bool[] memory isERC1155s = new bool[](2);
        isERC1155s[0] = false;
        isERC1155s[1] = true;

        // Identify tokenID to hibernate
        uint8 bundleId = hb.addBundle(tokenAddresses, tokenIDs, isERC1155s);

        // Generate merkle roots..
        gk.addGate(bundleId, 0x6634ba781bc13377cfb2bd014862dd753df7b080d8bfddc9ed59e5b4ed966a16, 107, 0);
        gk.addGate(bundleId, 0x3bd1747adc06ad4a02e3eef59cde51b78aa1319c1e4aff7f88930be56c779c66, 1823, 1);
        gk.addGate(bundleId, 0x0, 0, 1); // dummy gate (for testing)
        gk.addGate(bundleId, 0x4234f797e4342f099b6fee4d7fd56d0e6b23d8700e6252f4a3b71fcb9c99f11d, 1420, 2);
        gk.addGate(bundleId, 0xf8216e27858bce2821c152437fd5dfaae5900227d288a6b668675e3ed2ca1e62, 1650, 2);

        // add gates w/ appropriate roots & stages to gatekeeper to gatekeeper.
        gr.startGame(honeybox);

        // Add bundle to gatekeeper
        nft.approve(address(hb), NFT_ID);
        sft.setApprovalForAll(address(hb), true);
        hb.puffPuffPassOut(bundleId);

        // Emergency enable gates
        // gk.setGateEnabled(0, 0, true);
        // gk.setGateEnabled(0, 1, true);
        // gk.setGateEnabled(0, 2, true);
        // gk.setGateEnabled(0, 3, true);
        // gk.setGateEnabled(0, 4, true);

        vm.stopBroadcast();
    }
}
