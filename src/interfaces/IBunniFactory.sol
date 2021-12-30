// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IBunni} from "./IBunni.sol";
import {IERC20} from "./IERC20.sol";

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
    /// @notice Emitted when the protocol fee has been updated
    /// @param newProtocolFee The new protocol fee
    event SetProtocolFee(uint256 newProtocolFee);

    /// @notice Creates a Bunni contract. Cannot create two Bunnies with the exact same pool & ticks.
    /// @param name The ERC20 name of the Bunni LP token
    /// @param symbol The ERC20 symbol of the Bunni LP token
    /// @param pool The Uniswap V3 pool to create the Bunni for
    /// @param tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return bunni The created Bunni contract
    function createBunni(
        string calldata name,
        string calldata symbol,
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) external returns (IBunni bunni);

    /// @notice Fetches an existing Bunni with the given parameters. Returns address(0) if
    /// a Bunni with the given parameters doesn't exist.
    /// @param pool The Uniswap V3 pool the Bunni is for
    /// @param tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return bunni The Bunni contract
    function getBunni(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (IBunni bunni);

    /// @notice Sweeps ERC20 token balances to a recipient. Mainly used for extracting protocol fees.
    /// Only callable by the owner.
    /// @param tokenList The list of ERC20 tokens to sweep
    /// @param recipient The token recipient address
    function sweepTokens(IERC20[] calldata tokenList, address recipient)
        external;

    /// @notice Updates the protocol fee value. Scaled by 1e18. Only callable by the owner.
    /// @param value The new protocol fee value
    function setProtocolFee(uint256 value) external;

    /// @notice Returns the protocol fee value. Decimal value <1, scaled by 1e18.
    function protocolFee() external returns (uint256);
}
