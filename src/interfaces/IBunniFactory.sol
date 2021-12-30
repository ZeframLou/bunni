// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool, IBunni} from "../Bunni.sol";

/// @title BunniFactory
/// @author zefram.eth
/// @notice Factory contract for creating Bunni contracts
interface IBunniFactory {
    /// @notice Emitted when a Bunni has been created
    /// @param name The ERC20 name of the Bunni LP token
    /// @param symbol The ERC20 symbol of the Bunni LP token
    /// @param pool The Uniswap V3 pool to create the Bunni for
    /// @param tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @param bunni The created Bunni contract
    event CreateBunni(
        string name,
        string symbol,
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        IBunni bunni
    );

    /// @notice Creates a Bunni contract. Cannot create two Bunnies with the exact same pool & ticks.
    /// @param _name The ERC20 name of the Bunni LP token
    /// @param _symbol The ERC20 symbol of the Bunni LP token
    /// @param _pool The Uniswap V3 pool to create the Bunni for
    /// @param _tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param _tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return bunni The created Bunni contract
    function createBunni(
        string calldata _name,
        string calldata _symbol,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) external returns (IBunni bunni);

    /// @notice Fetches an existing Bunni with the given parameters. Returns address(0) if
    /// a Bunni with the given parameters doesn't exist.
    /// @param _pool The Uniswap V3 pool the Bunni is for
    /// @param _tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param _tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return bunni The Bunni contract
    function getBunni(
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) external view returns (IBunni bunni);
}
