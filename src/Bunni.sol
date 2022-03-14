// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {ERC20} from "./lib/ERC20.sol";
import {IBunni} from "./interfaces/IBunni.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {IBunniFactory} from "./interfaces/IBunniFactory.sol";
import {LiquidityManagement} from "./uniswap/LiquidityManagement.sol";

/// @title Bunni
/// @author zefram.eth
/// @notice A fractionalized Uniswap v3 LP position represented by an ERC20 token.
/// Supports compounding trading fees earned back into the liquidity position.
contract Bunni is IBunni, ERC20 {
    uint8 public constant SHARE_DECIMALS = 18;
    uint256 public constant SHARE_PRECISION = 10**SHARE_DECIMALS;
    uint256 public constant WAD = 10**18;

    address public immutable override factory;

    constructor(
        string memory _name,
        string memory _symbol,
        address _factory
    ) ERC20(_name, _symbol, SHARE_DECIMALS) {
        factory = _factory;
    }

    /// -----------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------

    function mint(address to, uint256 amount) external {
        require(msg.sender == factory, "factory");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == factory, "factory");
        _burn(from, amount);
    }

    /// @inheritdoc IBunni
    function pricePerFullShare()
        external
        view
        virtual
        override
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 existingShareSupply = totalSupply;
        if (existingShareSupply == 0) {
            return (0, 0, 0);
        }

        (liquidity, , , , ) = pool.positions(positionKey);
        // liquidity is uint128, SHARE_PRECISION uses 60 bits
        // so liquidity * SHARE_PRECISION can't overflow 256 bits
        liquidity = uint128(
            (liquidity * SHARE_PRECISION) / existingShareSupply
        );
        (amount0, amount1, ) = _getReserves(liquidity);
    }

    /// @inheritdoc IBunni
    function getReserves()
        public
        view
        override
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        (uint128 existingLiquidity, , , , ) = pool.positions(positionKey);
        return _getReserves(existingLiquidity);
    }

    /// -----------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------

    /// @notice Mints share tokens (this) to the recipient based on the amount of liquidity added.
    /// @param recipient The recipient of the share tokens
    /// @param addedLiquidity The amount of liquidity added
    /// @param existingLiquidity The amount of existing liquidity before the add
    /// @return shares The amount of share tokens minted to the sender.
    function _mintShares(
        address recipient,
        uint128 addedLiquidity,
        uint128 existingLiquidity
    ) internal virtual returns (uint256 shares) {
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
        _mint(recipient, shares);
    }

    /// @notice Cast a uint256 to a uint112, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint112
    function _toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y);
    }

    /// @dev See getReserves
    function _getReserves(uint128 existingLiquidity)
        internal
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtRatioX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                existingLiquidity
            );

        reserve0 = _toUint112(amount0);
        reserve1 = _toUint112(amount1);
        blockTimestampLast = uint32(block.timestamp);
    }
}
