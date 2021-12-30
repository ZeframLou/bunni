// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {PeripheryPayments, PeripheryImmutableState} from "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import {ILiquidityManagement} from "../interfaces/ILiquidityManagement.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
abstract contract LiquidityManagement is
    ILiquidityManagement,
    PeripheryPayments
{
    /// @notice The Uniswap v3 pool
    IUniswapV3Pool public immutable override pool;
    /// @notice The Uniswap pool's token0
    address public immutable override token0;
    /// @notice The Uniswap pool's token1
    address public immutable override token1;
    /// @notice The lower tick of the liquidity position
    int24 public immutable override tickLower;
    /// @notice The upper tick of the liquidity position
    int24 public immutable override tickUpper;

    constructor(
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper,
        address _factory,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {
        pool = _pool;
        token0 = _pool.token0();
        token1 = _pool.token1();
        tickLower = _tickLower;
        tickUpper = _tickUpper;
    }

    struct MintCallbackData {
        address payer;
    }

    /// @inheritdoc IUniswapV3MintCallback
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        require(msg.sender == address(pool), "WHO");

        if (amount0Owed > 0)
            pay(token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            pay(token1, decoded.payer, msg.sender, amount1Owed);
    }

    struct AddLiquidityParams {
        address recipient;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    function _addLiquidity(AddLiquidityParams memory params)
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData({payer: msg.sender}))
        );

        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "Price slippage check"
        );
    }
}
