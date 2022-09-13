// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {ERC20} from "../../lib/ERC20.sol";

contract ERC20Mock is ERC20("", "", 18) {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
