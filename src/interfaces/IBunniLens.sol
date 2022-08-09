// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;
pragma abicoder v2;

import "../base/Structs.sol";
import {IBunniHub} from "./IBunniHub.sol";

/// @title BunniLens
/// @author zefram.eth
/// @notice Helper functions for fetching info about Bunni positions
interface IBunniLens {
    /// @notice The BunniHub that the lens contract reads from
    function hub() external view returns (IBunniHub);

    /// @notice Computes the amount of liquidity and token amounts each full share token
    /// can be redeemed for when calling withdraw().
    /// @param key The Bunni position's key
    /// @return liquidity_ The liquidity amount that each full share is worth
    /// @return amount0 The amount of token0 that each full share can be redeemed for
    /// @return amount1 The amount of token1 that each full share can be redeemed for
    function pricePerFullShare(BunniKey calldata key)
        external
        view
        returns (
            uint128 liquidity_,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Returns the token reserve in the liquidity position.
    /// @param key The Bunni position's key
    /// @return reserve0 The amount of token0 in the liquidity position
    /// @return reserve1 The amount of token1 in the liquidity position
    function getReserves(BunniKey calldata key)
        external
        view
        returns (uint112 reserve0, uint112 reserve1);
}
