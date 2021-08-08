// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH9Mock is ERC20("", "") {
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);
        msg.sender.transfer(wad);
    }
}
