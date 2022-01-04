// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import {LowGasSafeMath} from "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

import {IWETH9} from "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";

import {IBunni} from "./interfaces/IBunni.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {IBunniMigrator} from "./interfaces/IBunniMigrator.sol";

contract BunniMigrator is IBunniMigrator {
    using LowGasSafeMath for uint256;

    address public immutable override WETH9;

    constructor(address _WETH9) {
        WETH9 = _WETH9;
    }

    receive() external payable {
        require(msg.sender == WETH9, "Not WETH9");
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
        uint256 amount0V2ToMigrate = amount0V2.mul(params.percentageToMigrate) /
            100;
        uint256 amount1V2ToMigrate = amount1V2.mul(params.percentageToMigrate) /
            100;

        // approve the position manager up to the maximum token amounts
        SafeTransferLib.safeApprove(
            IERC20(params.token0),
            params.bunni,
            amount0V2ToMigrate
        );
        SafeTransferLib.safeApprove(
            IERC20(params.token1),
            params.bunni,
            amount1V2ToMigrate
        );

        // mint v3 position via Bunni

        uint256 amount0V3;
        uint256 amount1V3;
        (sharesMinted, , amount0V3, amount1V3) = IBunni(params.bunni).deposit(
            IBunni.DepositParams({
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
                    params.bunni,
                    0
                );
            }

            uint256 refund0 = amount0V2 - amount0V3;
            if (params.refundAsETH && params.token0 == WETH9) {
                IWETH9(WETH9).withdraw(refund0);
                SafeTransferLib.safeTransferETH(msg.sender, refund0);
            } else {
                SafeTransferLib.safeTransfer(
                    IERC20(params.token0),
                    msg.sender,
                    refund0
                );
            }
        }
        if (amount1V3 < amount1V2) {
            if (amount1V3 < amount1V2ToMigrate) {
                SafeTransferLib.safeApprove(
                    IERC20(params.token1),
                    params.bunni,
                    0
                );
            }

            uint256 refund1 = amount1V2 - amount1V3;
            if (params.refundAsETH && params.token1 == WETH9) {
                IWETH9(WETH9).withdraw(refund1);
                SafeTransferLib.safeTransferETH(msg.sender, refund1);
            } else {
                SafeTransferLib.safeTransfer(
                    IERC20(params.token1),
                    msg.sender,
                    refund1
                );
            }
        }
    }
}
