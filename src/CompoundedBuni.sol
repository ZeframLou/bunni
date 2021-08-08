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
    /// @notice how many uncollected fee tokens are owed to the position, as of the last computation
    uint128 public feesOwed0;
    uint128 public feesOwed1;

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

    struct WithdrawParams {
        uint256 shares;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Decreases the amount of liquidity in the position and sends the tokens to the sender.
    /// @param params tokenId The ID of the token for which liquidity is being decreased,
    /// shares The amount of ERC20 tokens (this) to burn,
    /// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
    /// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return liquidityReduction The amount of liquidity decrease
    /// @return amount0 The amount of token0 accounted to the position's tokens owed
    /// @return amount1 The amount of token1 accounted to the position's tokens owed
    function withdraw(WithdrawParams calldata params)
        external
        returns (
            uint128 liquidityReduction,
            uint256 amount0,
            uint256 amount1
        )
    {
        return _withdraw(params);
    }

    function withdrawOneside() external {}

    function compound() external {}

    /// @dev See {CompoundedBuni::deposit}
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

        // update position
        feesOwed0 += uint128(
            FullMath.mulDiv(
                updatedFeeGrowthInside0LastX128 - feeGrowthInside0LastX128,
                existingLiquidity,
                FixedPoint128.Q128
            )
        );
        feesOwed1 += uint128(
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

    /// @dev See {CompoundedBuni::withdraw}
    function _withdraw(WithdrawParams calldata params)
        internal
        returns (
            uint128 liquidityReduction,
            uint256 amount0,
            uint256 amount1
        )
    {
        // burn shares
        require(params.shares > 0);
        uint256 currentTotalSupply = totalSupply();
        _burn(msg.sender, params.shares);
        // at this point of execution we know param.shares <= currentTotalSupply
        // since otherwise the _burn() call would've reverted

        // burn liquidity from pool
        uint128 positionLiquidity = liquidity;
        // type cast is safe because we know liquidityReduction <= positionLiquidity
        liquidityReduction = uint128(
            FullMath.mulDiv(
                positionLiquidity,
                params.shares,
                currentTotalSupply
            )
        );
        (amount0, amount1) = pool.burn(
            tickLower,
            tickUpper,
            liquidityReduction
        );
        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "Price slippage check"
        );

        // update position
        // this is now updated to the current transaction
        (
            ,
            uint256 updatedFeeGrowthInside0LastX128,
            uint256 updatedFeeGrowthInside1LastX128,
            ,

        ) = pool.positions(positionKey);
        feesOwed0 += uint128(
            FullMath.mulDiv(
                updatedFeeGrowthInside0LastX128 - feeGrowthInside0LastX128,
                positionLiquidity,
                FixedPoint128.Q128
            )
        );
        feesOwed1 += uint128(
            FullMath.mulDiv(
                updatedFeeGrowthInside1LastX128 - feeGrowthInside1LastX128,
                positionLiquidity,
                FixedPoint128.Q128
            )
        );
        feeGrowthInside0LastX128 = updatedFeeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = updatedFeeGrowthInside1LastX128;
        // subtraction is safe because we checked positionLiquidity >= liquidityReduction
        liquidity = positionLiquidity - liquidityReduction;

        // pay tokens to sender
        pay(token0, address(this), msg.sender, amount0);
        pay(token1, address(this), msg.sender, amount1);
    }

    function _withdrawOneside() internal {}

    function _compound() internal {}

    /// @notice Mints share tokens (this) to the sender based on the amount of liquidity added.
    /// @param newLiquidity The amount of liquidity added
    /// @param existingLiquidity The amount of existing liquidity before the add
    /// @return shares The amount of share tokens minted to the sender.
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
