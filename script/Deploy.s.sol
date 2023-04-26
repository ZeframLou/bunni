// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CREATE3Factory} from "create3-factory/src/CREATE3Factory.sol";

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
        CREATE3Factory create3 = CREATE3Factory(
            0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf
        );
        IUniswapV3Factory factory = IUniswapV3Factory(
            vm.envAddress("UNIV3_FACTORY")
        );
        address owner = vm.envAddress("OWNER");
        uint256 protocolFee = vm.envUint("PROTOCOL_FEE");

        vm.startBroadcast(deployerPrivateKey);

        hub = BunniHub(
            create3.deploy(
                keccak256("BunniHub-v1.0.2"),
                bytes.concat(
                    type(BunniHub).creationCode,
                    abi.encode(factory, owner, protocolFee)
                )
            )
        );
        lens = BunniLens(
            create3.deploy(
                keccak256("BunniLens-v1.0.2"),
                bytes.concat(type(BunniLens).creationCode, abi.encode(hub))
            )
        );
        migrator = BunniMigrator(
            create3.deploy(
                keccak256("BunniMigrator-v1.0.2"),
                bytes.concat(type(BunniMigrator).creationCode, abi.encode(hub))
            )
        );

        vm.stopBroadcast();
    }
}
