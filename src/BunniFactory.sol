// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IBunni, Bunni} from "./Bunni.sol";
import {IBunniFactory} from "./interfaces/IBunniFactory.sol";

/// @title BunniFactory
/// @author zefram.eth
/// @notice Factory contract for creating Bunni contracts
contract BunniFactory is IBunniFactory {
    address internal immutable WETH9;
    mapping(bytes32 => IBunni) internal createdBunnies;

    constructor(address _WETH9) {
        WETH9 = _WETH9;
    }

    /// @inheritdoc IBunniFactory
    function createBunni(
        string calldata _name,
        string calldata _symbol,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) external override returns (IBunni bunni) {
        bytes32 bunniKey = _computeBunniKey(_pool, _tickLower, _tickUpper);
        require(address(createdBunnies[bunniKey]) == address(0), "EXISTS");
        bunni = new Bunni(
            _name,
            _symbol,
            _pool,
            _tickLower,
            _tickUpper,
            address(this),
            WETH9
        );
        createdBunnies[bunniKey] = bunni;
        emit CreateBunni(_name, _symbol, _pool, _tickLower, _tickUpper, bunni);
    }

    /// @inheritdoc IBunniFactory
    function getBunni(
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) external view override returns (IBunni bunni) {
        return createdBunnies[_computeBunniKey(_pool, _tickLower, _tickUpper)];
    }

    /// @notice Computes the unique kaccak256 hash of a Bunni contract.
    /// @param _pool The Uniswap V3 pool
    /// @param _tickLower The lower tick of the Bunni's UniV3 LP position
    /// @param _tickUpper The upper tick of the Bunni's UniV3 LP position
    /// @return The bytes32 hash
    function _computeBunniKey(
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_pool, _tickLower, _tickUpper));
    }
}
