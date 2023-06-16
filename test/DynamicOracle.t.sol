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
import {TickMath} from "@uniswap/core-next/contracts/libraries/TickMath.sol";

contract TestDynamicOracle is Test {

    int24 constant MAX_TICK_SPACING = 32767;
    uint160 constant SQRT_RATIO_1_1 =  79228162514264337593543950336;

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

        manager.initialize(key, SQRT_RATIO_1_1);

        swapRouter = new PoolSwapTest(manager);

        token0.approve(address(dynamicOracle), type(uint256).max);
        token1.approve(address(dynamicOracle), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
    }

    /**
     * @notice Test to check if dynamic fees. 
     * Fees is increasing linearly with time
     */
    function testDynamicFee() public {

        uint24 oldFee = dynamicOracle.getFee(key);
        vm.warp(200);
        uint24 newFee = dynamicOracle.getFee(key);

        assertGt(newFee, oldFee, "New Fee should be greater than old Fee");
    }

    /**
     * @notice Test to check if swap is updating price feeds in oracle Hook
     */
    function testPriceFeedAfterSwap() public {
        

        vm.warp(200);
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(false, 1e18, SQRT_RATIO_1_1 + 1),
            PoolSwapTest.TestSettings(true, true)
        );

        uint160 oldPrice = dynamicOracle.latestAnswer(id); 
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(false, 1e18, SQRT_RATIO_1_1 + 2),
            PoolSwapTest.TestSettings(true, true)
        );

        uint160 newPrice = dynamicOracle.latestAnswer(id);

        assertEq(newPrice, SQRT_RATIO_1_1 + 2);
        assertGt(newPrice, oldPrice, "New Price should be greater than old Price");
        
    }
    /**
     * @notice Test to check full oracle updates
     */
    function testOracleAfterSwap() public {
                
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(false, 1e18, SQRT_RATIO_1_1 + 1),
            PoolSwapTest.TestSettings(true, true)
        );

        uint256 oldRoundId =    dynamicOracle.latestRound(id); 
        uint256 oldTime    =    dynamicOracle.latestTimestamp(id);

        vm.warp(2000);

        swapRouter.swap(
            key,
            IPoolManager.SwapParams(false, 1e18, SQRT_RATIO_1_1 + 2),
            PoolSwapTest.TestSettings(true, true)
        );

        uint256 newRoundId  =    dynamicOracle.latestRound(id); 
        uint256 newTime     =    dynamicOracle.latestTimestamp(id);

        assertGt(newRoundId, oldRoundId, "New RoundId should be greater than old RoundId");
        assertEq(newTime - oldTime, 2000 - 1);

        /**
        emit log_uint(dynamicOracle.latestRound(id));
        emit log_uint(dynamicOracle.latestAnswer(id));
        emit log_uint(dynamicOracle.latestTimestamp(id));
        */
    }
}