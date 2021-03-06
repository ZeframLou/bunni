// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.6;
pragma abicoder v2;

import {DSTest} from "ds-test/test.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {Bunni} from "../Bunni.sol";
import {SwapRouter} from "./lib/SwapRouter.sol";
import {IBunni} from "../interfaces/IBunni.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {WETH9Mock} from "./mocks/WETH9Mock.sol";
import {BunniFactory} from "../BunniFactory.sol";
import {BunniMigrator} from "../BunniMigrator.sol";
import {UniswapDeployer} from "./lib/UniswapDeployer.sol";
import {IBunniFactory} from "../interfaces/IBunniFactory.sol";
import {IBunniMigrator} from "../interfaces/IBunniMigrator.sol";

contract BunniMigratorTest is DSTest, UniswapDeployer {
    uint256 constant PRECISION = 10**18;
    uint8 constant DECIMALS = 18;
    uint256 constant PROTOCOL_FEE = 5e17;
    uint256 constant EPSILON = 10**13;

    // tokens
    ERC20Mock token0;
    ERC20Mock token1;
    WETH9Mock weth;

    // uniswap v3
    IUniswapV3Factory factory;
    IUniswapV3Pool pool;
    SwapRouter router;
    uint24 fee;

    // uniswap v2
    IUniswapV2Factory v2Factory;
    IUniswapV2Router02 v2Router;
    IUniswapV2Pair v2Pair;

    // bunni
    IBunniFactory bunniFactory;
    IBunni bunni;
    BunniMigrator migrator;

    function setUp() public {
        // initialize uniswap v3
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
        weth = new WETH9Mock();
        router = new SwapRouter(address(factory), address(weth));

        // initialize uniswap v2
        v2Factory = IUniswapV2Factory(deployUniswapV2Factory(address(this)));
        v2Router = IUniswapV2Router02(
            deployUniswapV2Router(address(v2Factory), address(weth))
        );
        v2Pair = IUniswapV2Pair(
            v2Factory.createPair(address(token0), address(token1))
        );

        // initialize migrator
        migrator = new BunniMigrator(address(weth));

        // initialize bunni factory
        bunniFactory = new BunniFactory(address(weth), PROTOCOL_FEE);

        // initialize bunni
        bunni = bunniFactory.createBunni(
            "Bunni LP",
            "BUNNI-LP",
            pool,
            -10000,
            10000
        );

        // approve token0
        token0.approve(address(bunni), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token0.approve(address(migrator), type(uint256).max);
        token0.approve(address(v2Router), type(uint256).max);

        // approve token1
        token1.approve(address(bunni), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        token1.approve(address(migrator), type(uint256).max);
        token1.approve(address(v2Router), type(uint256).max);

        // approve uni v2 LP to migrator
        v2Pair.approve(address(migrator), type(uint256).max);

        // provide liquidity on uni v2
        uint256 mintAmount = 1000 * PRECISION;
        token0.mint(address(this), mintAmount);
        token1.mint(address(this), mintAmount);
        v2Router.addLiquidity(
            address(token0),
            address(token1),
            mintAmount,
            mintAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function test_migrate() public {
        uint256 sharesMinted = migrator.migrate(
            IBunniMigrator.MigrateParams({
                pair: address(v2Pair),
                liquidityToMigrate: v2Pair.balanceOf(address(this)),
                percentageToMigrate: 100,
                token0: address(token0),
                token1: address(token1),
                bunni: address(bunni),
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp,
                refundAsETH: false
            })
        );

        // check added uni v3 liquidity
        uint256 mintAmount = 1000 * PRECISION;
        uint256 minLP = 1001;
        (uint112 reserve0, uint112 reserve1, ) = bunni.getReserves();
        assertEqDecimal(uint256(reserve0), mintAmount - minLP, DECIMALS);
        assertEqDecimal(uint256(reserve1), mintAmount - minLP, DECIMALS);

        // check shares
        assertEqDecimal(bunni.balanceOf(address(this)), sharesMinted, DECIMALS);
        assertEqDecimal(sharesMinted, bunni.totalSupply(), DECIMALS);
    }
}
