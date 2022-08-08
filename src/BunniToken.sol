// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import "./base/Structs.sol";
import {ERC20} from "./lib/ERC20.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IBunniToken} from "./interfaces/IBunniToken.sol";

/// @title BunniToken
/// @author zefram.eth
/// @notice ERC20 token that represents a user's LP position
contract BunniToken is IBunniToken, ERC20 {
    IUniswapV3Pool public immutable override pool;
    int24 public immutable override tickLower;
    int24 public immutable override tickUpper;
    address public immutable override hub;

    constructor(BunniKey memory key_)
        ERC20(
            string(
                abi.encodePacked(
                    "Bunni ",
                    IERC20(key_.pool.token0()).symbol(),
                    "/",
                    IERC20(key_.pool.token1()).symbol(),
                    " LP"
                )
            ),
            "BUNNI-LP",
            18
        )
    {
        pool = key_.pool;
        tickLower = key_.tickLower;
        tickUpper = key_.tickUpper;
        hub = msg.sender;
    }

    function mint(address to, uint256 amount) external override {
        require(msg.sender == hub, "WHO");

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override {
        require(msg.sender == hub, "WHO");

        _burn(from, amount);
    }
}
