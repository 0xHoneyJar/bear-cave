// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {GameRegistry} from "src/GameRegistry.sol";
import {HibernationDen} from "src/HibernationDen.sol";
import {HoneyJarPortal} from "src/HoneyJarPortal.sol";
import {Constants} from "src/Constants.sol";

// Sets up HibernationDen as a game
contract ConfigureGame is THJScriptBase("gen3") {
    using stdJson for string;
    using SafeCastLib for uint256;

    // Copied from the portal
    enum MessageTypes {
        SEND_NFT,
        START_GAME,
        SET_FERMENTED_JARS
    }

    // Dependencies
    ERC721 private nft;
    ERC1155 private sft;
    ERC20 private token;

    function setUp() public {}

    function run(string calldata env) public override {
        string memory json = _getConfig(env);

        bytes32 vrfKeyhash = json.readBytes32(".vrf.keyHash");
        uint64 vrfSubId = json.readUint(".vrf.subId").safeCastTo64();
        HibernationDen.VRFConfig memory vrfConfig = HibernationDen.VRFConfig(vrfKeyhash, vrfSubId, 3, 10000000);

        HibernationDen.MintConfig memory mintConfig =
            abi.decode(json.parseRaw(".mintConfig"), (HibernationDen.MintConfig));

        HibernationDen hibernationDen = HibernationDen(payable(json.readAddress(".deployments.den")));
        HoneyJarPortal portal = HoneyJarPortal(payable(json.readAddress(".deployments.portal")));
        GameRegistry registry = GameRegistry(json.readAddress(".deployments.registry"));

        vm.startBroadcast();

        hibernationDen.initialize(vrfConfig, mintConfig);
        registry.grantRole(Constants.PORTAL, address(portal));
        registry.grantRole(Constants.BURNER, address(portal));
        registry.grantRole(Constants.MINTER, address(portal));
        registry.registerGame(address(hibernationDen));

        vm.stopBroadcast();
    }

    // Note: only ETH
    function configurePortals(string calldata envL1, string calldata envL2) public {
        string memory l1Json = _getConfig(envL1);
        string memory l2Json = _getConfig(envL2);

        uint256 l1ChainId = l1Json.readUint(".chainId");
        uint256 l2ChainId = l2Json.readUint(".chainId");

        HoneyJarPortal portalL1 = HoneyJarPortal(payable(l1Json.readAddress(".deployments.portal")));
        HoneyJarPortal portalL2 = HoneyJarPortal(payable(l2Json.readAddress(".deployments.portal")));

        vm.startBroadcast();
        portalL1.setMinDstGas(portalL1.lzChainId(l2ChainId), uint16(MessageTypes.SEND_NFT), 225000);
        portalL1.setTrustedRemote(portalL1.lzChainId(l2ChainId), abi.encodePacked(address(portalL2), address(portalL1)));

        vm.stopBroadcast();

        // For some reason doesn't work on arb
        // vm.startBroadcast();
        // portalL2.setMinDstGas(portalL2.lzChainId(l1ChainId), uint16(MessageTypes.SEND_NFT), 225000);
        // cast abi-encode "method(address,address)" 0x1399706d571ae4E915f32099995eE0ad9107AD96 0xc5c9ac6a978957AD0F4004C7D798a9D9141FFb22
        // portalL2.setTrustedRemote(portalL2.lzChainId(l1ChainId), abi.encodePacked(address(portalL1), address(portalL2)));

        // vm.stopBroadcast();
    }
}
