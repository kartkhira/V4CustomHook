// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {TestERC20} from "@uniswap/core-next/contracts/test/TestERC20.sol";
import {PoolManager} from "@uniswap/core-next/contracts/PoolManager.sol";
import {PoolModifyPositionTest} from "@uniswap/core-next/contracts/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "@uniswap/core-next/contracts/test/PoolSwapTest.sol";
import {DynamicOracle} from "../src/hooks/DynamicOracle.sol";
import {CurrencyLibrary, Currency} from "@uniswap/core-next/contracts/libraries/CurrencyLibrary.sol";
import {PoolId} from "@uniswap/core-next/contracts/libraries/PoolId.sol";
import {DynamicOracleImplementation} from "./implementation/DynamicOracleImplementation.sol";
import {IPoolManager} from "@uniswap/core-next/contracts/interfaces/IPoolManager.sol";
import {Test} from "forge-std/Test.sol";
import {Hooks} from "@uniswap/core-next/contracts/libraries/Hooks.sol";

contract TestDynamicOracle is Test {


    int24 constant MAX_TICK_SPACING = 32767;
    uint160 constant SQRT_RATIO_10_1 = 250541448375047931186413801569;

    TestERC20 token0;
    TestERC20 token1;
    PoolManager manager;

    IPoolManager.PoolKey key;
    bytes32 id;

    PoolSwapTest swapRouter;

    DynamicOracleImplementation dynamicOracle = DynamicOracleImplementation(
        address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_MODIFY_POSITION_FLAG| Hooks.AFTER_SWAP_FLAG
            )
        )
    );

    function setUp() public {

        token0 = new TestERC20(2**128);
        token1 = new TestERC20(2**128);
        manager = new PoolManager(500000);

        // Implementing dynamic fees starting at 0
        key = IPoolManager.PoolKey(
            Currency.wrap(address(token0)), Currency.wrap(address(token1)), type(uint24).max, MAX_TICK_SPACING, dynamicOracle
        );

        id = PoolId.toId(key);

        DynamicOracleImplementation impl = new DynamicOracleImplementation(manager, dynamicOracle);
        (, bytes32[] memory writes) = vm.accesses(address(impl));
        vm.etch(address(dynamicOracle), address(impl).code);
        // for each storage key that was written during the hook implementation, copy the value over
        unchecked {
            for (uint256 i = 0; i < writes.length; i++) {
                bytes32 slot = writes[i];
                vm.store(address(dynamicOracle), slot, vm.load(address(impl), slot));
            }
        }

        manager.initialize(key, SQRT_RATIO_10_1);

        swapRouter = new PoolSwapTest(manager);

        token0.approve(address(dynamicOracle), type(uint256).max);
        token1.approve(address(dynamicOracle), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
    }

    function testDynamicFee() public {

        uint24 oldFee = dynamicOracle.getFee(key);
        vm.warp(200);
        uint24 newFee = dynamicOracle.getFee(key);

        assertGt(newFee, oldFee, "New Fee should be greater than old Fee");
    }

    function testOracleAfterSwap() public {
        
    }
}