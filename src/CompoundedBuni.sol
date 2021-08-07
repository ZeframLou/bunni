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
    /// @notice Initializes this contract.
    function initialize(
        string calldata _name,
        string calldata _symbol,
        IUniswapV3Pool _pool,
        address _WETH9
    ) external initializer {
        // init parent contracts
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __LiquidityManagement_init(_pool, _WETH9);
    }

    function deposit(uint256 token0Amount, uint256 token1Amount)
        external
        returns (uint256 mintAmount)
    {
        uint128 liquidity = _deposit(token0Amount, token1Amount);
        return _mintShares(liquidity);
    }

    function depositOneside() external {}

    function withdraw() external {}

    function withdrawOneside() external {}

    function compound() external {}

    function _deposit(uint256 token0Amount, uint256 token1Amount)
        internal
        returns (uint128 liquidityAmount)
    {}

    function _depositOneside() internal {}

    function _withdraw() internal {}

    function _withdrawOneside() internal {}

    function _compound() internal {}

    function _mintShares(uint128 liquidity)
        internal
        returns (uint256 mintAmount)
    {
        return 0;
    }
}
