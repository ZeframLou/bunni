// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {IMulticall} from "@uniswap/v3-periphery/contracts/interfaces/IMulticall.sol";
import {ISelfPermit} from "@uniswap/v3-periphery/contracts/interfaces/ISelfPermit.sol";

import {IERC20} from "./IERC20.sol";
import {ILiquidityManagement} from "./ILiquidityManagement.sol";

/// @title Bunni
/// @author zefram.eth
/// @notice A fractionalized Uniswap v3 LP position represented by an ERC20 token.
/// Supports one-sided liquidity adding and compounding fees earned back into the
/// liquidity position.
interface IBunni is ILiquidityManagement, IERC20, IMulticall {
    /// @notice Emitted when liquidity is increased via deposit
    /// @param sender The msg.sender address
    /// @param liquidity The amount by which liquidity was increased
    /// @param amount0 The amount of token0 that was paid for the increase in liquidity
    /// @param amount1 The amount of token1 that was paid for the increase in liquidity
    /// @param shares The amount of share tokens minted to the sender
    event Deposit(
        address indexed sender,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    /// @notice Emitted when liquidity is decreased via withdrawal
    /// @param sender The msg.sender address
    /// @param liquidity The amount by which liquidity was decreased
    /// @param recipient The address of the account that received the collected tokens
    /// @param amount0 The amount of token0 that was accounted for the decrease in liquidity
    /// @param amount1 The amount of token1 that was accounted for the decrease in liquidity
    /// @param shares The amount of share tokens burnt from the sender
    event Withdraw(
        address indexed sender,
        address recipient,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    /// @notice Emitted when fees are compounded back into liquidity
    /// @param sender The msg.sender address
    /// @param liquidity The amount by which liquidity was increased
    /// @param amount0 The amount of token0 added to the liquidity position
    /// @param amount1 The amount of token1 added to the liquidity position
    event Compound(
        address indexed sender,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    struct DepositParams {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params amount0Desired The desired amount of token0 to be spent,
    /// amount1Desired The desired amount of token1 to be spent,
    /// amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
    /// amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return shares The new tokens (this) minted to the sender
    /// @return addedLiquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function deposit(DepositParams calldata params)
        external
        payable
        returns (
            uint256 shares,
            uint128 addedLiquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct WithdrawParams {
        address recipient;
        uint256 shares;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Decreases the amount of liquidity in the position and sends the tokens to the sender.
    /// If withdrawing ETH, need to follow up with unwrapWETH9() and sweepToken()
    /// @param params recipient The user if not withdrawing ETH, address(0) if withdrawing ETH
    /// shares The amount of ERC20 tokens (this) to burn,
    /// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
    /// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return removedLiquidity The amount of liquidity decrease
    /// @return amount0 The amount of token0 withdrawn to the recipient
    /// @return amount1 The amount of token1 withdrawn to the recipient
    function withdraw(WithdrawParams calldata params)
        external
        returns (
            uint128 removedLiquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Claims the trading fees earned and uses it to add liquidity.
    /// @return addedLiquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 added to the liquidity position
    /// @return amount1 The amount of token1 added to the liquidity position
    function compound()
        external
        returns (
            uint128 addedLiquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Computes the amount of liquidity and token amounts each full share token
    /// can be redeemed for when calling withdraw().
    /// @return liquidity_ The liquidity amount that each full share is worth
    /// @return amount0 The amount of token0 that each full share can be redeemed for
    /// @return amount1 The amount of token1 that each full share can be redeemed for
    function pricePerFullShare()
        external
        view
        returns (
            uint128 liquidity_,
            uint256 amount0,
            uint256 amount1
        );
}
