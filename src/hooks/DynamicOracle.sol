// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPoolManager} from "@uniswap/core-next/contracts/interfaces/IPoolManager.sol";
import {IDynamicFeeManager} from "@uniswap/core-next/contracts/interfaces/IDynamicFeeManager.sol";
import {Hooks} from "@uniswap/core-next/contracts/libraries/Hooks.sol";
import {BaseHook} from "../BaseHook.sol";
import {IAggregatorInterface} from "../interfaces/IAggregatorInterface.sol";
import {TickMath} from "@uniswap/core-next/contracts/libraries/TickMath.sol";
import {BalanceDelta} from "@uniswap/core-next/contracts/types/BalanceDelta.sol";
import {PoolId} from "@uniswap/core-next/contracts/libraries/PoolId.sol";
import {console} from "forge-std/console.sol";

contract DynamicOracle is BaseHook, IDynamicFeeManager, IAggregatorInterface {

    error MustUseDynamicFee();
    uint256 deployTimestamp;
    uint24 feeCount;
    using PoolId for IPoolManager.PoolKey;

    event OracleInitialized(address indexed poolManager, uint256 deployTimestamp);
    event OracleDataAdded(bytes32 indexed key, uint160 value, uint256 timestamp);

    /// @notice Oracle pools do not have fees because they exist to serve as an oracle for a pair of tokens
    error OnlyOneOraclePoolAllowed();

    /// @notice Oracle positions must be full range
    error OraclePositionsMustBeFullRange();

    /// @notice Oracle pools must have liquidity locked so that they cannot become more susceptible to price manipulation
    error OraclePoolMustLockLiquidity();


    mapping(bytes32 => mapping(uint256 => uint160)) roundData;
    mapping(bytes32 => uint256) latestStamp;
    mapping(bytes32 => mapping(uint256 => uint256)) roundIdTimestamp;
    mapping(bytes32 => uint256) roundIds;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        deployTimestamp = block.timestamp;
        emit OracleInitialized(address(_poolManager), deployTimestamp);

    }

    /**
     * Returns the dynamic fee. Called Before swap
     */
    function getFee(IPoolManager.PoolKey calldata) external view returns (uint24) {
        uint24 startingFee = 3000;
        uint256 lapsed = block.timestamp - deployTimestamp;
        uint24 totalFee = startingFee + (uint24(lapsed) * 100) / (60); // 100 bps a mi
        return totalFee >= 1000000 ? 1000000 : totalFee;
    }


    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: true,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: true,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }


    /**
     * This Hook makes sure dynamic fees is enabled
     * @param key Pool Key
     */
    function beforeInitialize(address, IPoolManager.PoolKey calldata key, uint160 price)
        external
        view
        override
        poolManagerOnly
        returns (bytes4)
    {
        // This is to limit the fragmentation of pools using this oracle hook. In other words,
        // there may only be one pool per pair of tokens that use this hook. The tick spacing is set to the maximum
        // because we only allow max range liquidity in this pool.
        if (key.fee != Hooks.DYNAMIC_FEE || key.tickSpacing != poolManager.MAX_TICK_SPACING()) revert OnlyOneOraclePoolAllowed();
        return DynamicOracle.beforeInitialize.selector;
    }

    function afterModifyPosition(
        address,
        IPoolManager.PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params,
        BalanceDelta 
    ) external override poolManagerOnly returns (bytes4) {
        if (params.liquidityDelta < 0) revert OraclePoolMustLockLiquidity();
        int24 maxTickSpacing = poolManager.MAX_TICK_SPACING();
        if (
            params.tickLower != TickMath.minUsableTick(maxTickSpacing)
                || params.tickUpper != TickMath.maxUsableTick(maxTickSpacing)
        ) revert OraclePositionsMustBeFullRange();
        return DynamicOracle.afterModifyPosition.selector;
    }

    function afterSwap(address, 
                       IPoolManager.PoolKey calldata key, 
                       IPoolManager.SwapParams calldata,
                       BalanceDelta)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        _updateOracle(key);
        return DynamicOracle.afterSwap.selector;
    }

    function _updateOracle(IPoolManager.PoolKey calldata key) internal {

        bytes32 id = key.toId();
        (uint160 currentPrice,,) = poolManager.getSlot0(id);
        _addData(keccak256(abi.encode(key)), currentPrice);
    }

    function _addData(bytes32 key, uint160 val) internal {

        uint256 timeStamp = block.timestamp;

        roundData[key][roundIds[key]] = val;
        latestStamp[key] = timeStamp;
        roundIdTimestamp[key][roundIds[key]] = timeStamp;
        roundIds[key]++;

        emit OracleDataAdded(key,val, timeStamp);
    }

    function latestAnswer(bytes32 key) external view returns(uint160) {

        //bytes32 pKey = keccak256(abi.encode(key));
        return roundData[key][roundIds[key]-1];
    }

    function latestTimestamp(bytes32 key) external view returns(uint256) {

        return latestStamp[key];
    }

    function getAnswer(bytes32 key, 
                        uint256 roundId) 
                        external view returns (uint160){


        return roundData[key][roundId];          

    }

    function latestRound(bytes32 key) external view returns (uint256){

        return roundIds[key];

    }

    function getTimestamp(bytes32 key, 
                          uint256 roundId) 
                          external view returns (uint256){
        
        return roundIdTimestamp[key][roundId];
    }
}
