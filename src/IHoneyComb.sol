// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface IHoneyComb is IERC721 {
    function mint(address to) external returns (uint256);

    function batchMint(address to, uint8 amount) external;

    function burn(uint256 _id) external;
}
