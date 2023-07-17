// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Constants} from "src/Constants.sol";

contract BearPouch is GameRegistryConsumer {
    using SafeERC20 for IERC20;

    using FixedPointMathLib for uint256;

    address private jani;
    address private beekeeper;
    uint256 private honeyJarShare;

    IERC20 public paymentToken;

    constructor(address gameRegistry_, address paymentToken_, address jani_, address beekeeper_, uint256 honeyJarShare_)
        GameRegistryConsumer(gameRegistry_)
    {
        paymentToken = IERC20(paymentToken_);
        jani = jani_;
        beekeeper = beekeeper_;
        honeyJarShare = honeyJarShare_;
    }

    function distribute(uint256 amountERC20) external payable onlyRole(Constants.GAME_INSTANCE) {
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
}
