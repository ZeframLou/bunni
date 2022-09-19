// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/Script.sol";

import {BunniHub} from "../src/BunniHub.sol";
import {BunniLens} from "../src/BunniLens.sol";
import {BunniMigrator} from "../src/BunniMigrator.sol";

contract Deploy is Script {
    function run()
        external
        returns (
            BunniHub hub,
            BunniLens lens,
            BunniMigrator migrator
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        IUniswapV3Factory factory = IUniswapV3Factory(
            vm.envAddress("UNIV3_FACTORY")
        );
        address owner = vm.envAddress("OWNER");
        uint256 protocolFee = vm.envUint("PROTOCOL_FEE");

        vm.startBroadcast(deployerPrivateKey);

        hub = new BunniHub(factory, owner, protocolFee);
        lens = new BunniLens(hub);
        migrator = new BunniMigrator(hub);

        vm.stopBroadcast();
    }
}
