// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {GameRegistryConsumer} from "./GameRegistry.sol";
import {Constants} from "./GameLib.sol";

/// @title BearPouch
/// @notice A separate contract that an be used to manage funds/ accounting
/// @notice this contract is unused rn
abstract contract BearPouch is GameRegistryConsumer {
    address payable private jani;
    address payable private beekeeper;
    ERC20 private paymentToken;
    uint16 private honeycombShare; // in bps (10_000)
    uint256 private totalERC20Fees;
    uint256 private totalETHfees;

    constructor(address gameRegistery_, address jani_, address beekeeper_, ERC20 paymentToken_, uint16 honeycombShare_)
        GameRegistryConsumer(gameRegistery_)
    {
        paymentToken = paymentToken_;
        jani = payable(jani_);
        beekeeper = payable(beekeeper_);
        honeycombShare = honeycombShare_;
    }

    ///@dev Validating if the `amount_` is appropriate should be done upstream
    function processERC20Payment(address player_, uint256 amount_) external onlyRole(Constants.GAME_INSTANCE) {
        paymentToken.transferFrom(player_, address(this), amount_);
        totalERC20Fees += amount_;
    }

    /// @dev Validating if the `amount_` is appropriate should be done upstream
    function processETHPayment() external payable onlyRole(Constants.GAME_INSTANCE) {
        totalETHfees += msg.value;
    }

    function withdrawFunds() public returns (uint256) {
        // permissions check
        require(_hasRole(Constants.JANI) || _hasRole(Constants.BEEKEEPER), "oogabooga you can't do that");
        require(beekeeper != address(0), "withdrawFunds::beekeeper address not set");
        require(jani != address(0), "withdrawFunds::jani address not set");

        uint256 currBalance = paymentToken.balanceOf(address(this));
        require(currBalance > 0, "oogabooga theres nothing here");

        // ETh balanec

        // xfer everything all at once so we don't have to worry about accounting
        paymentToken.transfer(beekeeper, currBalance * honeycombShare / 10_000);
        paymentToken.transfer(jani, (currBalance * (10_000 - honeycombShare)) / 10_000); // This should be everything

        return paymentToken.balanceOf(address(this));
    }

    function withdrawETH() public {
        require(_hasRole(Constants.JANI) || _hasRole(Constants.BEEKEEPER), "oogabooga you can't do that");
        require(beekeeper != address(0), "withdrawFunds::beekeeper address not set");
        require(jani != address(0), "withdrawFunds::jani address not set");

        uint256 ethBalance = address(this).balance;
        (bool success,) = beekeeper.call{value: ethBalance * honeycombShare / 10_000}("");
        require(success, "withdrawETH::Failed to send eth");

        (success,) = jani.call{value: (ethBalance * (10_000 - honeycombShare)) / 10_000}("");
        require(success, "withdrawETH::Failed to send eth");
    }
}
