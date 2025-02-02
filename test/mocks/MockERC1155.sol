// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function uri(uint256) public pure virtual override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public {
        _mint(to, id, amount, data);
    }

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        _batchMint(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) public {
        _burn(from, id, amount);
    }

    function batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) public {
        _batchBurn(from, ids, amounts);
    }
}
