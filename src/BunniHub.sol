// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {SelfPermit} from "@uniswap/v3-periphery/contracts/base/SelfPermit.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {Owned} from "solmate/auth/Owned.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import "./base/Structs.sol";
import {BunniToken} from "./BunniToken.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IBunniHub} from "./interfaces/IBunniHub.sol";
import {IBunniToken} from "./interfaces/IBunniToken.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {LiquidityManagement} from "./uniswap/LiquidityManagement.sol";

/// @title BunniHub
/// @author zefram.eth
/// @notice The main contract LPs interact with. Each BunniKey corresponds to a BunniToken,
/// which is the ERC20 LP token for the Uniswap V3 position specified by the BunniKey.
/// Use deposit()/withdraw() to mint/burn LP tokens, and use compound() to compound the swap fees
/// back into the LP position.
contract BunniHub is
    IBunniHub,
    Owned,
    Multicall,
    SelfPermit,
    LiquidityManagement
{
    uint256 internal constant WAD = 1e18;
    uint256 internal constant MAX_PROTOCOL_FEE = 5e17;

    /// -----------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------

    uint256 public override protocolFee;

    /// -----------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "OLD");
        _;
    }

    /// -----------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------

    constructor(address owner_, uint256 protocolFee_) Owned(owner_) {
        protocolFee = protocolFee_;
    }

    /// -----------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------

    /// @inheritdoc IBunniHub
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
        (uint128 existingLiquidity, , , , ) = params.key.pool.positions(
            keccak256(
                abi.encodePacked(
                    address(this),
                    params.key.tickLower,
                    params.key.tickUpper
                )
            )
        );
        (addedLiquidity, amount0, amount1) = _addLiquidity(
            LiquidityManagement.AddLiquidityParams({
                key: params.key,
                recipient: address(this),
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );
        shares = _mintShares(
            params.key,
            params.recipient,
            addedLiquidity,
            existingLiquidity
        );

        emit Deposit(
            msg.sender,
            params.recipient,
            keccak256(abi.encode(params.key)),
            addedLiquidity,
            amount0,
            amount1,
            shares
        );
    }

    /// @inheritdoc IBunniHub
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
        IBunniToken shareToken = getBunniToken(params.key);
        require(address(shareToken) != address(0), "WHAT");

        uint256 currentTotalSupply = shareToken.totalSupply();
        (uint128 existingLiquidity, , , , ) = params.key.pool.positions(
            keccak256(
                abi.encodePacked(
                    address(this),
                    params.key.tickLower,
                    params.key.tickUpper
                )
            )
        );

        // burn shares
        require(params.shares > 0, "0");
        shareToken.burn(msg.sender, params.shares);
        // at this point of execution we know param.shares <= currentTotalSupply
        // since otherwise the burn() call would've reverted

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
        (amount0, amount1) = params.key.pool.burn(
            params.key.tickLower,
            params.key.tickUpper,
            removedLiquidity
        );
        // collect tokens and give to msg.sender
        (amount0, amount1) = params.key.pool.collect(
            params.recipient,
            params.key.tickLower,
            params.key.tickUpper,
            uint128(amount0),
            uint128(amount1)
        );
        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "SLIP"
        );

        emit Withdraw(
            msg.sender,
            params.recipient,
            keccak256(abi.encode(params.key)),
            removedLiquidity,
            amount0,
            amount1,
            params.shares
        );
    }

    /// @inheritdoc IBunniHub
    function compound(BunniKey calldata key)
        external
        virtual
        override
        returns (
            uint128 addedLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 protocolFee_ = protocolFee;

        // trigger an update of the position fees owed snapshots if it has any liquidity
        key.pool.burn(key.tickLower, key.tickUpper, 0);
        (, , , uint128 cachedFeesOwed0, uint128 cachedFeesOwed1) = key
            .pool
            .positions(
                keccak256(
                    abi.encodePacked(
                        address(this),
                        key.tickLower,
                        key.tickUpper
                    )
                )
            );

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
            (uint160 sqrtRatioX96, , , , , , ) = key.pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(key.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(key.tickUpper);

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
        (amount0, amount1) = key.pool.collect(
            address(this),
            key.tickLower,
            key.tickUpper,
            uint128(amount0),
            uint128(amount1)
        );

        /// -----------------------------------------------------------
        /// amount0, amount1 now store the fees claimed
        /// -----------------------------------------------------------

        if (protocolFee_ > 0) {
            // take fee from amount0 and amount1 and transfer to factory
            // amount0 uses 128 bits, protocolFee uses 60 bits
            // so amount0 * protocolFee can't overflow 256 bits
            uint256 fee0 = (amount0 * protocolFee_) / WAD;
            uint256 fee1 = (amount1 * protocolFee_) / WAD;

            // add fees (minus protocol fees) to Uniswap pool
            (addedLiquidity, amount0, amount1) = _addLiquidity(
                LiquidityManagement.AddLiquidityParams({
                    key: key,
                    recipient: address(this),
                    amount0Desired: amount0 - fee0,
                    amount1Desired: amount1 - fee1,
                    amount0Min: 0,
                    amount1Min: 0
                })
            );

            // the protocol fees are now stored in the factory itself
            // and can be withdrawn by the owner via sweepTokens()

            // emit event
            emit PayProtocolFee(fee0, fee1);
        } else {
            // add fees to Uniswap pool
            (addedLiquidity, amount0, amount1) = _addLiquidity(
                LiquidityManagement.AddLiquidityParams({
                    key: key,
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

        emit Compound(
            msg.sender,
            keccak256(abi.encode(key)),
            addedLiquidity,
            amount0,
            amount1
        );
    }

    /// @inheritdoc IBunniHub
    function deployBunniToken(BunniKey calldata key)
        public
        override
        returns (IBunniToken token)
    {
        bytes32 bunniKeyHash = keccak256(abi.encode(key));

        token = IBunniToken(
            CREATE3.deploy(
                bunniKeyHash,
                abi.encodePacked(
                    type(BunniToken).creationCode,
                    abi.encode(this, key)
                ),
                0
            )
        );

        emit NewBunni(
            token,
            bunniKeyHash,
            key.pool,
            key.tickLower,
            key.tickUpper
        );
    }

    /// -----------------------------------------------------------------------
    /// View functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc IBunniHub
    function getBunniToken(BunniKey calldata key)
        public
        view
        override
        returns (IBunniToken token)
    {
        token = IBunniToken(CREATE3.getDeployed(keccak256(abi.encode(key))));

        uint256 tokenCodeLength;
        assembly {
            tokenCodeLength := extcodesize(token)
        }

        if (tokenCodeLength == 0) {
            return IBunniToken(address(0));
        }
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc IBunniHub
    function sweepTokens(IERC20[] calldata tokenList, address recipient)
        external
        override
        onlyOwner
    {
        uint256 tokenListLength = tokenList.length;
        for (uint256 i; i < tokenListLength; ) {
            SafeTransferLib.safeTransfer(
                tokenList[i],
                recipient,
                tokenList[i].balanceOf(address(this))
            );

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IBunniHub
    function setProtocolFee(uint256 value) external override onlyOwner {
        require(value <= MAX_PROTOCOL_FEE, "MAX");
        protocolFee = value;
        emit SetProtocolFee(value);
    }

    /// -----------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------

    /// @notice Mints share tokens to the recipient based on the amount of liquidity added.
    /// @param key The Bunni position's key
    /// @param recipient The recipient of the share tokens
    /// @param addedLiquidity The amount of liquidity added
    /// @param existingLiquidity The amount of existing liquidity before the add
    /// @return shares The amount of share tokens minted to the sender.
    function _mintShares(
        BunniKey calldata key,
        address recipient,
        uint128 addedLiquidity,
        uint128 existingLiquidity
    ) internal virtual returns (uint256 shares) {
        IBunniToken shareToken = getBunniToken(key);
        require(address(shareToken) != address(0), "WHAT");

        uint256 existingShareSupply = shareToken.totalSupply();
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
        shareToken.mint(recipient, shares);
    }
}
