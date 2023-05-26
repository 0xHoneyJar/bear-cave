// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

abstract contract CrossChainTHJ {
    uint256 private immutable _chainId;

    function getChainId() internal view returns (uint256) {
        return _chainId;
    }

    constructor() {
        _chainId = block.chainid;
    }
}
