// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.5;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";

import {IPeripheryPayments} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
interface ILiquidityManagement is IUniswapV3MintCallback, IPeripheryPayments {
    /// @notice The Uniswap v3 pool
    function pool() external view returns (IUniswapV3Pool);

    /// @notice The Uniswap pool's token0
    function token0() external view returns (address);

    /// @notice The Uniswap pool's token1
    function token1() external view returns (address);

    /// @notice The lower tick of the liquidity position
    function tickLower() external view returns (int24);

    /// @notice The upper tick of the liquidity position
    function tickUpper() external view returns (int24);
}
