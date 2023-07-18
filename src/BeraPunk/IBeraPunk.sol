// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC721A} from "ERC721A/IERC721A.sol";

interface IBeraPunk is IERC721A {
    function mintOne(address to) external returns (uint256);

    function batchMint(address to, uint256 amount) external;

    function nextTokenId() external view returns (uint256);
}
