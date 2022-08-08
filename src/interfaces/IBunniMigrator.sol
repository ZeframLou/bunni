// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;
pragma abicoder v2;

import "../base/Structs.sol";
import {IBunniHub} from "./IBunniHub.sol";

/// @title BunniMigrator
/// @author zefram.eth
/// @notice Migrates Uniswap v2 LP tokens to Bunni LP tokens
interface IBunniMigrator {
    struct MigrateParams {
        address pair; // the Uniswap v2-compatible pair
        uint256 liquidityToMigrate; // expected to be balanceOf(msg.sender)
        uint8 percentageToMigrate; // represented as a numerator over 100
        address token0;
        address token1;
        BunniKey key;
        uint256 amount0Min; // must be discounted by percentageToMigrate
        uint256 amount1Min; // must be discounted by percentageToMigrate
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }

    /// @notice Migrates liquidity to v3 by burning v2 liquidity and minting a new position for v3 using Bunni
    /// @dev Slippage protection is enforced via `amount{0,1}Min`, which should be a discount of the expected values of
    /// the maximum amount of v3 liquidity that the v2 liquidity can get. For the special case of migrating to an
    /// out-of-range position, `amount{0,1}Min` may be set to 0, enforcing that the position remains out of range
    /// @param params The params necessary to migrate v2 liquidity, encoded as `MigrateParams` in calldata
    /// @return sharesMinted The amount of Bunni LP tokens minted
    function migrate(MigrateParams calldata params)
        external
        returns (uint256 sharesMinted);

    function hub() external view returns (IBunniHub);

    function WETH9() external view returns (address);
}
