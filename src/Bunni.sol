// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {SelfPermit} from "@uniswap/v3-periphery/contracts/base/SelfPermit.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {PeripheryValidation} from "@uniswap/v3-periphery/contracts/base/PeripheryValidation.sol";

import {ERC20} from "./lib/ERC20.sol";
import {IBunni} from "./interfaces/IBunni.sol";
import {LiquidityManagement} from "./uniswap/LiquidityManagement.sol";

/// @title Bunni
/// @author zefram.eth
/// @notice A fractionalized Uniswap v3 LP position represented by an ERC20 token.
/// Supports compounding trading fees earned back into the liquidity position.
contract Bunni is
    IBunni,
    ERC20,
    LiquidityManagement,
    Multicall,
    PeripheryValidation,
    SelfPermit
{
    uint8 public constant SHARE_DECIMALS = 18;
    uint256 public constant SHARE_PRECISION = 10**SHARE_DECIMALS;

    /// @notice the key of this LP position in the Uniswap pool
    bytes32 public immutable positionKey;

    constructor(
        string memory _name,
        string memory _symbol,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper,
        address _factory,
        address _WETH9
    )
        ERC20(_name, _symbol, SHARE_DECIMALS)
        LiquidityManagement(_pool, _tickLower, _tickUpper, _factory, _WETH9)
    {
        positionKey = PositionKey.compute(
            address(this),
            _tickLower,
            _tickUpper
        );
    }

    /// -----------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------

    /// @inheritdoc IBunni
    function deposit(DepositParams calldata params)
        external
        payable
        virtual
        override
        checkDeadline(params.deadline)
        returns (
            uint256 shares,
            uint128 addedLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (uint128 existingLiquidity, , , , ) = pool.positions(positionKey);
        (addedLiquidity, amount0, amount1) = _addLiquidity(
            LiquidityManagement.AddLiquidityParams({
                recipient: address(this),
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );
        shares = _mintShares(addedLiquidity, existingLiquidity);

        emit Deposit(msg.sender, addedLiquidity, amount0, amount1, shares);
    }

    /// @inheritdoc IBunni
    function withdraw(WithdrawParams calldata params)
        external
        virtual
        override
        checkDeadline(params.deadline)
        returns (
            uint128 removedLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 currentTotalSupply = totalSupply;
        (uint128 existingLiquidity, , , , ) = pool.positions(positionKey);

        // allow collecting to address(this) with address 0
        // this is used for withdrawing ETH
        address recipient = params.recipient == address(0)
            ? address(this)
            : params.recipient;

        // burn shares
        require(params.shares > 0, "0");
        _burn(msg.sender, params.shares);
        // at this point of execution we know param.shares <= currentTotalSupply
        // since otherwise the _burn() call would've reverted

        // burn liquidity from pool
        // type cast is safe because we know removedLiquidity <= existingLiquidity
        removedLiquidity = uint128(
            FullMath.mulDiv(
                existingLiquidity,
                params.shares,
                currentTotalSupply
            )
        );
        // burn liquidity
        // tokens are now collectable in the pool
        (amount0, amount1) = pool.burn(tickLower, tickUpper, removedLiquidity);
        // collect tokens and give to msg.sender
        (amount0, amount1) = pool.collect(
            recipient,
            tickLower,
            tickUpper,
            uint128(amount0),
            uint128(amount1)
        );
        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "SLIPPAGE"
        );

        emit Withdraw(
            msg.sender,
            recipient,
            removedLiquidity,
            amount0,
            amount1,
            params.shares
        );
    }

    /// @inheritdoc IBunni
    function compound()
        external
        virtual
        override
        returns (
            uint128 addedLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // trigger an update of the position fees owed snapshots if it has any liquidity
        pool.burn(tickLower, tickUpper, 0);
        (, , , uint128 cachedFeesOwed0, uint128 cachedFeesOwed1) = pool
            .positions(positionKey);

        /// -----------------------------------------------------------
        /// amount0, amount1 are multi-purposed, see comments below
        /// -----------------------------------------------------------
        amount0 = cachedFeesOwed0;
        amount1 = cachedFeesOwed1;

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the updated amounts of fee owed
        /// -----------------------------------------------------------

        // the fee is likely not balanced (i.e. tokens will be left over after adding liquidity)
        // so here we compute which token to fully claim and which token to partially claim
        // so that we only claim the amounts we need

        {
            (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            if (sqrtRatioX96 <= sqrtRatioAX96) {
                // token0 used fully, token1 used partially
                // compute liquidity using amount0
                uint128 liquidityIncrease = LiquidityAmounts
                    .getLiquidityForAmount0(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        amount0
                    );
                amount1 = LiquidityAmounts.getAmount1ForLiquidity(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidityIncrease
                );
            } else if (sqrtRatioX96 < sqrtRatioBX96) {
                // uncertain which token is used fully
                // compute liquidity using both amounts
                // and then use the lower one
                uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
                    sqrtRatioX96,
                    sqrtRatioBX96,
                    amount0
                );
                uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(
                    sqrtRatioAX96,
                    sqrtRatioX96,
                    amount1
                );

                if (liquidity0 < liquidity1) {
                    // token0 used fully, token1 used partially
                    // compute liquidity using amount0
                    amount1 = LiquidityAmounts.getAmount1ForLiquidity(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        liquidity0
                    );
                } else {
                    // token0 used partially, token1 used fully
                    // compute liquidity using amount1
                    amount0 = LiquidityAmounts.getAmount0ForLiquidity(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        liquidity1
                    );
                }
            } else {
                // token0 used partially, token1 used fully
                // compute liquidity using amount1
                uint128 liquidityIncrease = LiquidityAmounts
                    .getLiquidityForAmount1(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        amount1
                    );
                amount0 = LiquidityAmounts.getAmount0ForLiquidity(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidityIncrease
                );
            }
        }

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the amount of fees to claim
        /// -----------------------------------------------------------

        // the actual amounts collected are returned
        // tokens are transferred to address(this)
        (amount0, amount1) = pool.collect(
            address(this),
            tickLower,
            tickUpper,
            uint128(amount0),
            uint128(amount1)
        );

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the fees claimed
        /// -----------------------------------------------------------

        // add fees to Uniswap pool
        (addedLiquidity, amount0, amount1) = _addLiquidity(
            LiquidityManagement.AddLiquidityParams({
                recipient: address(this),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the tokens added as liquidity
        /// -----------------------------------------------------------

        emit Compound(msg.sender, addedLiquidity, amount0, amount1);
    }

    /// @inheritdoc IBunni
    function pricePerFullShare()
        external
        view
        virtual
        override
        returns (
            uint128 liquidity_,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 existingShareSupply = totalSupply;
        (uint128 existingLiquidity, , , , ) = pool.positions(positionKey);

        // compute liquidity per share
        if (existingShareSupply == 0) {
            // no existing shares, bootstrap at rate 1:1
            liquidity_ = uint128(FixedPoint128.Q128);
        } else {
            // liquidity_ = existingLiquidity / existingShareSupply;
            liquidity_ = uint128(
                FullMath.mulDiv(
                    existingLiquidity,
                    SHARE_PRECISION,
                    existingShareSupply
                )
            );
        }

        // compute token amounts
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity_
        );
    }

    /// -----------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------

    /// @notice Mints share tokens (this) to the sender based on the amount of liquidity added.
    /// @param addedLiquidity The amount of liquidity added
    /// @param existingLiquidity The amount of existing liquidity before the add
    /// @return shares The amount of share tokens minted to the sender.
    function _mintShares(uint128 addedLiquidity, uint128 existingLiquidity)
        internal
        virtual
        returns (uint256 shares)
    {
        uint256 existingShareSupply = totalSupply;
        if (existingShareSupply == 0) {
            // no existing shares, bootstrap at rate 1:1
            shares = addedLiquidity;
        } else {
            // shares = existingShareSupply * addedLiquidity / existingLiquidity;
            shares = FullMath.mulDiv(
                existingShareSupply,
                addedLiquidity,
                existingLiquidity
            );
        }

        // mint shares to sender
        _mint(msg.sender, shares);
    }
}
