// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

abstract contract CrossChainTHJ {
    uint16 private immutable _chainId;

    function getChainId() internal view returns (uint16) {
        return _chainId;
    }

    constructor() {
        _chainId = SafeCastLib.safeCastTo16(block.chainid);
    }
}
