// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseHook} from "../../src/BaseHook.sol";
import {DynamicOracle} from "../../src/hooks/DynamicOracle.sol";
import {IPoolManager} from "@uniswap/core-next/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/core-next/contracts/libraries/Hooks.sol";

contract DynamicOracleImplementation is DynamicOracle {
    uint32 public time;

    constructor(IPoolManager _poolManager, DynamicOracle addressToEtch) DynamicOracle(_poolManager) {
        Hooks.validateHookAddress(addressToEtch, getHooksCalls());
    }

    // make this a no-op in testing
    function validateHookAddress(BaseHook _this) internal pure override {}

    function setTime(uint32 _time) external {
        time = _time;
    }

    function _blockTimestamp() internal view override returns (uint32) {
        return time;
    }
}