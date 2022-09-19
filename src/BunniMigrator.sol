// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import {IWETH9} from "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";

import {IERC20} from "./interfaces/IERC20.sol";
import {IBunniHub} from "./interfaces/IBunniHub.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {IBunniMigrator} from "./interfaces/IBunniMigrator.sol";

/// @title BunniMigrator
/// @author zefram.eth
/// @notice Migrates Uniswap v2 LP tokens to Bunni LP tokens
contract BunniMigrator is IBunniMigrator {
    IBunniHub public immutable override hub;

    constructor(IBunniHub hub_) {
        hub = hub_;
    }

    /// @inheritdoc IBunniMigrator
    function migrate(MigrateParams calldata params)
        external
        override
        returns (uint256 sharesMinted)
    {
        require(params.percentageToMigrate > 0, "SMOL_PP");
        require(params.percentageToMigrate <= 100, "BIG_PP");

        // burn v2 liquidity to this address
        IUniswapV2Pair(params.pair).transferFrom(
            msg.sender,
            params.pair,
            params.liquidityToMigrate
        );
        (uint256 amount0V2, uint256 amount1V2) = IUniswapV2Pair(params.pair)
            .burn(address(this));

        // calculate the amounts to migrate to v3
        uint256 amount0V2ToMigrate = (amount0V2 * params.percentageToMigrate) /
            100;
        uint256 amount1V2ToMigrate = (amount1V2 * params.percentageToMigrate) /
            100;

        // approve the position manager up to the maximum token amounts
        SafeTransferLib.safeApprove(
            IERC20(params.token0),
            address(hub),
            amount0V2ToMigrate
        );
        SafeTransferLib.safeApprove(
            IERC20(params.token1),
            address(hub),
            amount1V2ToMigrate
        );

        // mint v3 position via Bunni

        uint256 amount0V3;
        uint256 amount1V3;
        (sharesMinted, , amount0V3, amount1V3) = hub.deposit(
            IBunniHub.DepositParams({
                key: params.key,
                amount0Desired: amount0V2ToMigrate,
                amount1Desired: amount1V2ToMigrate,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: params.recipient,
                deadline: params.deadline
            })
        );

        // if necessary, clear allowance and refund dust
        if (amount0V3 < amount0V2) {
            if (amount0V3 < amount0V2ToMigrate) {
                SafeTransferLib.safeApprove(
                    IERC20(params.token0),
                    address(hub),
                    0
                );
            }

            uint256 refund0 = amount0V2 - amount0V3;
            SafeTransferLib.safeTransfer(
                IERC20(params.token0),
                msg.sender,
                refund0
            );
        }
        if (amount1V3 < amount1V2) {
            if (amount1V3 < amount1V2ToMigrate) {
                SafeTransferLib.safeApprove(
                    IERC20(params.token1),
                    address(hub),
                    0
                );
            }

            uint256 refund1 = amount1V2 - amount1V3;
            SafeTransferLib.safeTransfer(
                IERC20(params.token1),
                msg.sender,
                refund1
            );
        }
    }
}
