// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState is Initializable {
    /// @notice The Uniswap v3 pool
    IUniswapV3Pool public pool;
    /// @notice The Uniswap pool's token0
    address public token0;
    /// @notice The Uniswap pool's token1
    address public token1;
    /// @notice Wrapped Ether
    address public WETH9;

    function __PeripheryImmutableState_init(
        IUniswapV3Pool _pool,
        address _WETH9
    ) internal initializer {
        pool = _pool;
        token0 = _pool.token0();
        token1 = _pool.token1();
        WETH9 = _WETH9;
    }
}
