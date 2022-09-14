// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {SwapRouter} from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import "../base/Structs.sol";
import {BunniHub} from "../BunniHub.sol";
import {BunniLens} from "../BunniLens.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {IBunniHub} from "../interfaces/IBunniHub.sol";
import {IBunniLens} from "../interfaces/IBunniLens.sol";
import {IBunniToken} from "../interfaces/IBunniToken.sol";
import {UniswapDeployer} from "./lib/UniswapDeployer.sol";

contract BunniHubTest is Test, UniswapDeployer {
    uint256 constant PRECISION = 10**18;
    uint8 constant DECIMALS = 18;
    uint256 constant PROTOCOL_FEE = 5e17;
    uint256 constant EPSILON = 10**13;

    IUniswapV3Factory factory;
    IUniswapV3Pool pool;
    SwapRouter router;
    ERC20Mock token0;
    ERC20Mock token1;
    WETH weth;
    IBunniHub hub;
    IBunniLens lens;
    IBunniToken bunniToken;
    uint24 fee;
    BunniKey key;

    function setUp() public {
        // initialize uniswap
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();
        if (address(token0) >= address(token1)) {
            (token0, token1) = (token1, token0);
        }
        factory = IUniswapV3Factory(deployUniswapV3Factory());
        fee = 500;
        pool = IUniswapV3Pool(
            factory.createPool(address(token0), address(token1), fee)
        );
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
        weth = new WETH();
        router = new SwapRouter(address(factory), address(weth));

        // initialize bunni hub
        hub = new BunniHub(factory, address(this), PROTOCOL_FEE);

        // initialize bunni lens
        lens = new BunniLens(hub);

        // initialize bunni
        key = BunniKey({pool: pool, tickLower: -10000, tickUpper: 10000});
        bunniToken = hub.deployBunniToken(key);

        // approve tokens
        token0.approve(address(hub), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(hub), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
    }

    function test_deployBunniToken() public {
        hub.deployBunniToken(
            BunniKey({pool: pool, tickLower: -100, tickUpper: 100})
        );
    }

    function test_deposit() public {
        // make deposit
        uint256 depositAmount0 = PRECISION;
        uint256 depositAmount1 = PRECISION;
        (
            uint256 shares,
            uint128 newLiquidity,
            uint256 amount0,
            uint256 amount1
        ) = _makeDeposit(depositAmount0, depositAmount1);

        // check return values
        assertEqDecimal(shares, newLiquidity, DECIMALS);
        assertEqDecimal(amount0, depositAmount0, DECIMALS);
        assertEqDecimal(amount1, depositAmount1, DECIMALS);

        // check token balances
        assertEqDecimal(token0.balanceOf(address(this)), 0, DECIMALS);
        assertEqDecimal(token1.balanceOf(address(this)), 0, DECIMALS);
        assertEqDecimal(bunniToken.balanceOf(address(this)), shares, DECIMALS);
    }

    function test_withdraw() public {
        // make deposit
        uint256 depositAmount0 = PRECISION;
        uint256 depositAmount1 = PRECISION;
        (uint256 shares, , , ) = _makeDeposit(depositAmount0, depositAmount1);

        // withdraw
        IBunniHub.WithdrawParams memory withdrawParams = IBunniHub
            .WithdrawParams({
                key: key,
                recipient: address(this),
                shares: shares,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });
        (, uint256 withdrawAmount0, uint256 withdrawAmount1) = hub.withdraw(
            withdrawParams
        );

        // check return values
        // withdraw amount less than original due to rounding
        assertEqDecimal(withdrawAmount0, depositAmount0 - 1, DECIMALS);
        assertEqDecimal(withdrawAmount1, depositAmount1 - 1, DECIMALS);

        // check token balances
        assertEqDecimal(
            token0.balanceOf(address(this)),
            depositAmount0 - 1,
            DECIMALS
        );
        assertEqDecimal(
            token1.balanceOf(address(this)),
            depositAmount1 - 1,
            DECIMALS
        );
        assertEqDecimal(bunniToken.balanceOf(address(this)), 0, DECIMALS);
    }

    function test_compound() public {
        // make deposit
        uint256 depositAmount0 = PRECISION;
        uint256 depositAmount1 = PRECISION;
        _makeDeposit(depositAmount0, depositAmount1);

        // do a few trades to generate fees
        {
            // swap token0 to token1
            uint256 amountIn = PRECISION / 100;
            token0.mint(address(this), amountIn);
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(token0),
                    tokenOut: address(token1),
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            router.exactInputSingle(swapParams);
        }

        {
            // swap token1 to token0
            uint256 amountIn = PRECISION / 50;
            token1.mint(address(this), amountIn);
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(token1),
                    tokenOut: address(token0),
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            router.exactInputSingle(swapParams);
        }

        // compound
        (uint256 addedLiquidity, uint256 amount0, uint256 amount1) = hub
            .compound(key);

        // check added liquidity
        assertGtDecimal(addedLiquidity, 0, DECIMALS);
        assertGtDecimal(amount0, 0, DECIMALS);
        assertGtDecimal(amount1, 0, DECIMALS);

        // check token balances
        assertLeDecimal(token0.balanceOf(address(hub)), EPSILON, DECIMALS);
        assertLeDecimal(token1.balanceOf(address(hub)), EPSILON, DECIMALS);
    }

    function test_pricePerFullShare() public {
        // make deposit
        uint256 depositAmount0 = PRECISION;
        uint256 depositAmount1 = PRECISION;
        (
            uint256 shares,
            uint128 newLiquidity,
            uint256 newAmount0,
            uint256 newAmount1
        ) = _makeDeposit(depositAmount0, depositAmount1);

        (uint128 liquidity, uint256 amount0, uint256 amount1) = lens
            .pricePerFullShare(key);

        assertEqDecimal(
            liquidity,
            (newLiquidity * PRECISION) / shares,
            DECIMALS
        );
        assertEqDecimal(amount0, (newAmount0 * PRECISION) / shares, DECIMALS);
        assertEqDecimal(amount1, (newAmount1 * PRECISION) / shares, DECIMALS);
    }

    function _makeDeposit(uint256 depositAmount0, uint256 depositAmount1)
        internal
        returns (
            uint256 shares,
            uint128 newLiquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // mint tokens
        token0.mint(address(this), depositAmount0);
        token1.mint(address(this), depositAmount1);

        // deposit tokens
        // max slippage is 1%
        IBunniHub.DepositParams memory depositParams = IBunniHub.DepositParams({
            key: key,
            amount0Desired: depositAmount0,
            amount1Desired: depositAmount1,
            amount0Min: (depositAmount0 * 99) / 100,
            amount1Min: (depositAmount1 * 99) / 100,
            deadline: block.timestamp,
            recipient: address(this)
        });
        return hub.deposit(depositParams);
    }
}
