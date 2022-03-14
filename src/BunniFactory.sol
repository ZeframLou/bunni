// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {PeripheryImmutableState} from "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import {LiquidityManagement} from "@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol";

import {Bunni} from "./Bunni.sol";
import {IBunni} from "./interfaces/IBunni.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {IBunniFactory} from "./interfaces/IBunniFactory.sol";

/// @title BunniFactory
/// @author zefram.eth
/// @notice Factory contract for creating Bunni contracts
contract BunniFactory is IBunniFactory, LiquidityManagement, Ownable {
    uint256 internal constant MAX_PROTOCOL_FEE = 5e17;

    mapping(bytes32 => IBunni) internal createdBunnies;

    uint256 public override protocolFee;

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "OLD");
        _;
    }

    constructor(
        address _factory,
        address _WETH9,
        uint256 _protocolFee
    ) PeripheryImmutableState(_factory, _WETH9) {
        protocolFee = _protocolFee;
    }

    /// @inheritdoc IBunniFactory
    function createBunni(
        string calldata name,
        string calldata symbol,
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) external override returns (IBunni bunni) {
        bytes32 bunniKey = _computeBunniKey(pool, tickLower, tickUpper);
        require(address(createdBunnies[bunniKey]) == address(0), "EXISTS");
        bunni = new Bunni(name, symbol, address(this));
        createdBunnies[bunniKey] = bunni;
        emit CreateBunni(name, symbol, pool, tickLower, tickUpper, bunni);
    }

    struct DepositParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        address recipient;
    }

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
        (uint128 existingLiquidity, , , , ) = params.pool.positions(
            PositionKey.compute(
                address(this),
                params.tickLower,
                params.tickUpper
            )
        );
        (addedLiquidity, amount0, amount1, ) = addLiquidity(
            AddLiquidityParams({
                token0: params.pool.token0(),
                token1: params.pool.token1(),
                fee: params.pool.fee(),
                recipient: address(this),
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );
        shares = _mintShares(
            params.pool,
            params.recipient,
            params.tickLower,
            params.tickUpper,
            addedLiquidity,
            existingLiquidity
        );

        emit Deposit(
            msg.sender,
            params.recipient,
            addedLiquidity,
            amount0,
            amount1,
            shares
        );
    }

    struct WithdrawParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        address recipient;
        uint256 shares;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

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
        (uint128 existingLiquidity, , , , ) = params.pool.positions(
            PositionKey.compute(
                address(this),
                params.tickLower,
                params.tickUpper
            )
        );

        // allow collecting to address(this) with address 0
        // this is used for withdrawing ETH
        address recipient = params.recipient == address(0)
            ? address(this)
            : params.recipient;

        IBunni bunni = getBunni(pool, tickLower, tickUpper);
        uint256 currentTotalSupply = bunni.totalSupply();

        // burn shares
        require(params.shares > 0, "0");
        bunni.burn(msg.sender, params.shares);
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
            "SLIP"
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

    function _mintShares(
        IUniswapV3Pool pool,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 addedLiquidity,
        uint128 existingLiquidity
    ) internal virtual returns (uint256 shares) {
        IBunni bunni = getBunni(pool, tickLower, tickUpper);
        uint256 existingShareSupply = bunni.totalSupply();
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
        // mint shares to recipient
        bunni.mint(recipient, shares);
    }

    function compound(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    )
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

        uint256 _protocolFee = protocolFee;

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the fees claimed
        /// -----------------------------------------------------------

        if (_protocolFee > 0) {
            // take fee from amount0 and amount1 and transfer to factory
            // amount0 uses 128 bits, protocolFee uses 60 bits
            // so amount0 * protocolFee can't overflow 256 bits
            uint256 fee0 = (amount0 * protocolFee) / WAD;
            uint256 fee1 = (amount1 * _protocolFee) / WAD;

            // add fees (minus protocol fees) to Uniswap pool
            (addedLiquidity, amount0, amount1) = _addLiquidity(
                LiquidityManagement.AddLiquidityParams({
                    recipient: address(this),
                    amount0Desired: amount0 - fee0,
                    amount1Desired: amount1 - fee1,
                    amount0Min: 0,
                    amount1Min: 0
                })
            );

            // send protocol fees
            if (fee0 > 0) {
                SafeTransferLib.safeTransfer(ERC20(token0), factory, fee0);
            }
            if (fee1 > 0) {
                SafeTransferLib.safeTransfer(ERC20(token1), factory, fee1);
            }

            // emit event
            emit PayProtocolFee(fee0, fee1);
        } else {
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
        }

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the tokens added as liquidity
        /// -----------------------------------------------------------

        emit Compound(msg.sender, addedLiquidity, amount0, amount1);
    }

    /// @inheritdoc IBunniFactory
    function getBunni(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) public view override returns (IBunni bunni) {
        return createdBunnies[_computeBunniKey(pool, tickLower, tickUpper)];
    }

    /// @inheritdoc IBunniFactory
    function sweepTokens(IERC20[] calldata tokenList, address recipient)
        external
        override
        onlyOwner
    {
        for (uint256 i = 0; i < tokenList.length; i++) {
            SafeTransferLib.safeTransfer(
                tokenList[i],
                recipient,
                tokenList[i].balanceOf(address(this))
            );
        }
    }

    /// @inheritdoc IBunniFactory
    function setProtocolFee(uint256 value) external override onlyOwner {
        require(value <= MAX_PROTOCOL_FEE, "MAX");
        protocolFee = value;
        emit SetProtocolFee(value);
    }

    /// @notice Computes the unique kaccak256 hash of a Bunni contract.
    /// @param pool The Uniswap V3 pool
    /// @param tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return The bytes32 hash
    function _computeBunniKey(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(pool, tickLower, tickUpper));
    }
}
