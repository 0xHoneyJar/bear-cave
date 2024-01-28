// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SendTokens {
    function sendTokens(IERC721 erc721, address destination, uint256 startId, uint256 endId) public {
        for (uint256 tokenId = startId; tokenId <= endId; tokenId++) {
            erc721.transferFrom(msg.sender, destination, tokenId);
        }
    }
}
