// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.15;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../base/Structs.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeTransferLib} from "../lib/SafeTransferLib.sol";
import {ILiquidityManagement} from "../interfaces/ILiquidityManagement.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
abstract contract LiquidityManagement is ILiquidityManagement {
    using SafeTransferLib for IERC20;

    /// @param token0 The token0 of the Uniswap pool
    /// @param token1 The token1 of the Uniswap pool
    /// @param fee The fee tier of the Uniswap pool
    /// @param payer The address to pay for the required tokens
    struct MintCallbackData {
        address token0;
        address token1;
        uint24 fee;
        address payer;
    }

    IUniswapV3Factory public immutable override factory;

    constructor(IUniswapV3Factory factory_) {
        factory = factory_;
    }

    /// @inheritdoc IUniswapV3MintCallback
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        MintCallbackData memory decodedData = abi.decode(
            data,
            (MintCallbackData)
        );

        // verify caller
        address computedPool = factory.getPool(
            decodedData.token0,
            decodedData.token1,
            decodedData.fee
        );
        require(msg.sender == computedPool, "WHO");

        if (amount0Owed > 0)
            pay(decodedData.token0, decodedData.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            pay(decodedData.token1, decodedData.payer, msg.sender, amount1Owed);
    }

    /// @param key The Bunni position's key
    /// @param recipient The recipient of the liquidity position
    /// @param amount0Desired The token0 amount to use
    /// @param amount1Desired The token1 amount to use
    /// @param amount0Min The minimum token0 amount to use
    /// @param amount1Min The minimum token1 amount to use
    struct AddLiquidityParams {
        BunniKey key;
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
        if (params.amount0Desired == 0 && params.amount1Desired == 0) {
            return (0, 0, 0);
        }

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96, , , , , , ) = params.key.pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(
                params.key.tickLower
            );
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(
                params.key.tickUpper
            );

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }

        (amount0, amount1) = params.key.pool.mint(
            params.recipient,
            params.key.tickLower,
            params.key.tickUpper,
            liquidity,
            abi.encode(
                MintCallbackData({
                    token0: params.key.pool.token0(),
                    token1: params.key.pool.token1(),
                    fee: params.key.pool.fee(),
                    payer: msg.sender
                })
            )
        );

        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "SLIP"
        );
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            IERC20(token).safeTransfer(recipient, value);
        } else {
            // pull payment
            IERC20(token).safeTransferFrom(payer, recipient, value);
        }
    }
}
