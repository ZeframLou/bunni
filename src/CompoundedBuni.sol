// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {PeripheryValidation} from "@uniswap/v3-periphery/contracts/base/PeripheryValidation.sol";
import {SelfPermit} from "@uniswap/v3-periphery/contracts/base/SelfPermit.sol";

import {LiquidityManagement} from "./uniswap/LiquidityManagement.sol";

/// @author zefram.eth
/// @title Fractionalizes an Uniswap v3 LP position and autocompounds fees.
contract CompoundedBuni is
    ERC20PermitUpgradeable,
    LiquidityManagement,
    Multicall,
    PeripheryValidation,
    SelfPermit
{
    /// @notice the key of this LP position in the Uniswap pool
    bytes32 public positionKey;
    /// @notice the liquidity of the position
    uint128 public liquidity;
    /// @notice the fee growth of the aggregate position as of the last action on the individual position
    uint256 public feeGrowthInside0LastX128;
    uint256 public feeGrowthInside1LastX128;
    /// @notice how many uncollected tokens are owed to the position, as of the last computation
    uint128 public tokensOwed0;
    uint128 public tokensOwed1;

    /// @notice Initializes this contract.
    function initialize(
        string calldata _name,
        string calldata _symbol,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper,
        address _WETH9
    ) external initializer {
        // init parent contracts
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __LiquidityManagement_init(_pool, _tickLower, _tickUpper, _WETH9);

        // init self
        positionKey = PositionKey.compute(
            address(this),
            _tickLower,
            _tickUpper
        );
    }

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
    /// @return newLiquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function deposit(DepositParams calldata params)
        external
        payable
        checkDeadline(params.deadline)
        returns (
            uint256 shares,
            uint128 newLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint128 existingLiquidity = liquidity;
        (newLiquidity, amount0, amount1) = _deposit(params, existingLiquidity);
        shares = _mintShares(newLiquidity, existingLiquidity);
    }

    function depositOneside() external {}

    function withdraw() external {}

    function withdrawOneside() external {}

    function compound() external {}

    function _deposit(DepositParams calldata params, uint128 existingLiquidity)
        internal
        returns (
            uint128 newLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // add liquidity to Uniswap pool
        (newLiquidity, amount0, amount1) = _addLiquidity(
            LiquidityManagement.AddLiquidityParams({
                recipient: address(this),
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        // this is now updated to the current transaction
        (
            ,
            uint256 updatedFeeGrowthInside0LastX128,
            uint256 updatedFeeGrowthInside1LastX128,
            ,

        ) = pool.positions(positionKey);

        // record position info
        tokensOwed0 += uint128(
            FullMath.mulDiv(
                updatedFeeGrowthInside0LastX128 - feeGrowthInside0LastX128,
                existingLiquidity,
                FixedPoint128.Q128
            )
        );
        tokensOwed1 += uint128(
            FullMath.mulDiv(
                updatedFeeGrowthInside1LastX128 - feeGrowthInside1LastX128,
                existingLiquidity,
                FixedPoint128.Q128
            )
        );
        feeGrowthInside0LastX128 = updatedFeeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = updatedFeeGrowthInside1LastX128;
        liquidity = existingLiquidity + newLiquidity;
    }

    function _depositOneside() internal {}

    function _withdraw() internal {}

    function _withdrawOneside() internal {}

    function _compound() internal {}

    function _mintShares(uint128 newLiquidity, uint128 existingLiquidity)
        internal
        returns (uint256 shares)
    {
        uint256 existingShareSupply = totalSupply();
        if (existingShareSupply == 0) {
            // no existing shares, bootstrap at rate 1:1
            shares = newLiquidity;
        } else {
            // shares = existingShareSupply * newLiquidity / existingLiquidity;
            shares = FullMath.mulDiv(
                existingShareSupply,
                newLiquidity,
                existingLiquidity
            );
        }

        // mint shares to sender
        _mint(msg.sender, shares);
    }
}