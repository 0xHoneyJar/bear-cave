// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IBearPouch} from "src/interfaces/IBearPouch.sol";
import {GameRegistryConsumer} from "src/GameRegistryConsumer.sol";
import {Constants} from "src/Constants.sol";

contract BearPouch is IBearPouch, GameRegistryConsumer {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    error InvalidDistributionConfig(uint256 shareSum);
    error ZeroValue();

    IERC20 public paymentToken;

    DistributionConfig[] private distributions;

    constructor(address gameRegistry_, address paymentToken_, DistributionConfig[] memory _distributions)
        GameRegistryConsumer(gameRegistry_)
    {
        paymentToken = IERC20(paymentToken_);

        uint256 shareSum = 0;
        for (uint256 i = 0; i < _distributions.length; i++) {
            shareSum += _distributions[i].share;
        }

        if (shareSum != 1e18) revert InvalidDistributionConfig(shareSum);

        distributions = _distributions;
    }

    function distribute(uint256 amountERC20) external payable onlyRole(Constants.GAME_INSTANCE) {
        if (amountERC20 == 0 && msg.value == 0) revert ZeroValue();

        for (uint256 i = 0; i < distributions.length; i++) {
            // xFer the tokens
            if (amountERC20 != 0) {
                paymentToken.safeTransferFrom(
                    msg.sender, distributions[i].recipient, amountERC20.mulWadUp(distributions[i].share)
                );
            }

            // xfer the ETH
            if (msg.value != 0) {
                SafeTransferLib.safeTransferETH(
                    distributions[i].recipient, (msg.value).mulWadUp(distributions[i].share)
                );
            }
        }
    }
}
