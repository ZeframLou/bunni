// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Bunni} from "./Bunni.sol";
import {IBunni} from "./interfaces/IBunni.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {IBunniFactory} from "./interfaces/IBunniFactory.sol";

/// @title BunniFactory
/// @author zefram.eth
/// @notice Factory contract for creating Bunni contracts
contract BunniFactory is IBunniFactory, Ownable {
    uint256 internal constant MAX_PROTOCOL_FEE = 5e17;

    address internal immutable WETH9;
    mapping(bytes32 => IBunni) internal createdBunnies;

    uint256 public override protocolFee;

    constructor(address _WETH9, uint256 _protocolFee) {
        WETH9 = _WETH9;
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
        bunni = new Bunni(
            name,
            symbol,
            pool,
            tickLower,
            tickUpper,
            address(this),
            WETH9
        );
        createdBunnies[bunniKey] = bunni;
        emit CreateBunni(name, symbol, pool, tickLower, tickUpper, bunni);
    }

    /// @inheritdoc IBunniFactory
    function getBunni(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper
    ) external view override returns (IBunni bunni) {
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
