// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/mocks/VRFCoordinatorV2Mock.sol";

contract MockVRFCoordinator is VRFCoordinatorV2Mock {
    uint96 public constant MOCK_BASE_FEE = 100000000000000000;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;

    constructor() VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK) {}
}
