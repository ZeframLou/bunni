// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState is Initializable {
    /// @notice Wrapped Ether
    address public WETH9;

    function __PeripheryImmutableState_init(address _WETH9)
        internal
        initializer
    {
        WETH9 = _WETH9;
    }
}
