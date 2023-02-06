// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";

contract BearPouch is Owned {
    address private jani;
    address private beekeeper;
    ERC20 private paymentToken;
    uint256 private honeyShare; // in bps (10_000)

    constructor(address admin, address jani_, address beekeeper_, ERC20 paymentToken_, uint256 honeyShare_)
        Owned(admin)
    {
        paymentToken = paymentToken_;
        jani = jani_;
        beekeeper = beekeeper_;
        honeyShare = honeyShare_;
    }

    function withdrawFunds() public returns (uint256) {
        // permissions check
        require(msg.sender == jani || msg.sender == beekeeper, "oogabooga you can't do that");

        uint256 currBalance = paymentToken.balanceOf(address(this));
        uint256 balanceShare = 0;
        if (msg.sender == beekeeper) {
            balanceShare = currBalance * honeyShare / 10_000;
            paymentToken.transfer(beekeeper, balanceShare);
        } else if (msg.sender == owner) {
            balanceShare = currBalance * (10_000 - honeyShare) / 10_000;
            paymentToken.transfer(beekeeper, balanceShare);
        }

        return balanceShare;
    }
}
