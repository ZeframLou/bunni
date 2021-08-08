// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20("", "") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address, /*from*/
        address, /*to*/
        uint256 amount
    ) internal pure override {
        require(amount > 0, "ERC20Mock: amount 0");
    }
}
