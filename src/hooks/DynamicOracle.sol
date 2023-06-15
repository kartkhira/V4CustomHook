// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IPoolManager} from "@uniswap/core-next/contracts/interfaces/IPoolManager.sol";
import {IDynamicFeeManager} from "@uniswap/core-next/contracts/interfaces/IDynamicFeeManager.sol";
import {Hooks} from "@uniswap/core-next/contracts/libraries/Hooks.sol";
import {BaseHook} from "../BaseHook.sol";
import {Fees} from "@uniswap/core-next/contracts/libraries/Fees.sol";
import {IAggregatorInterface} from "../interfaces/IAggregatorInterface.sol";

contract DynamicOracle is BaseHook, IDynamicFeeManager, IAggregatorInterface {

    error MustUseDynamicFee();
    using Fees for uint24;
    uint32 deployTimestamp;

    /// @notice Oracle pools do not have fees because they exist to serve as an oracle for a pair of tokens
    error OnlyOneOraclePoolAllowed();

    /// @notice Oracle positions must be full range
    error OraclePositionsMustBeFullRange();

    /// @notice Oracle pools must have liquidity locked so that they cannot become more susceptible to price manipulation
    error OraclePoolMustLockLiquidity();


    mapping(bytes32 => mapping(uint256 => uint160)) roundData;
    mapping(bytes32 => uint256) latestTimestamp;
    mapping(bytes32 => uint256)roundIdTimestamp;
    mapping(bytes32 => uint256) roundId;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        deployTimestamp = _blockTimestamp();
    }

    /**
     * Returns the dynamic fee. Called Before swap
     */
    function getFee(IPoolManager.PoolKey calldata) external view returns (uint24) {
        uint24 startingFee = 3000;
        uint32 lapsed = _blockTimestamp() - deployTimestamp;

        uint24 totalFee = startingFee + (uint24(lapsed) * 10) / (60*24); // 10 bps a day
        return totalFee >= 1000000 ? 1000000 : totalFee;
    }

    /// @dev For mocking
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
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
            afterDonate: true
        });
    }

    /**
     * This Hook makes sure dynamic fees is enabled
     * @param key Pool Key
     */
    function beforeInitialize(address, IPoolManager.PoolKey calldata key, uint160)
        external
        pure
        override
        returns (bytes4)
    {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return DynamicOracle.beforeInitialize.selector;
    }

    function beforeInitialize(address, IPoolManager.PoolKey calldata key, uint160)
        external
        view
        override
        poolManagerOnly
        returns (bytes4)
    {
        // This is to limit the fragmentation of pools using this oracle hook. In other words,
        // there may only be one pool per pair of tokens that use this hook. The tick spacing is set to the maximum
        // because we only allow max range liquidity in this pool.
        if (key.fee != 0 || key.tickSpacing != poolManager.MAX_TICK_SPACING()) revert OnlyOneOraclePoolAllowed();
        return DynamicOracle.beforeInitialize.selector;
    }

    function afterModifyPosition(
        address,
        IPoolManager.PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params
    ) external override poolManagerOnly returns (bytes4) {
        if (params.liquidityDelta < 0) revert OraclePoolMustLockLiquidity();
        int24 maxTickSpacing = poolManager.MAX_TICK_SPACING();
        if (
            params.tickLower != TickMath.minUsableTick(maxTickSpacing)
                || params.tickUpper != TickMath.maxUsableTick(maxTickSpacing)
        ) revert OraclePositionsMustBeFullRange();
        _updateOracle(key);
        return DynamicOracle.afterModifyPosition.selector;
    }

    function afterSwap(address, IPoolManager.PoolKey calldata key, IPoolManager.SwapParams calldata)
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
        (uint160 currentPrice,) = poolManager.getSlot0(id);
        _addData(keccak256(abi.encode(key)), currentPrice);
    }

    function _addData(bytes32 key, uint160 val) internal {

        uint256 memory timeStamp = _blockTimestamp();

        roundData[key][roundId[key]] = val;
        latestTimestamp[key] = timeStamp;
        roundIdTimestamp[key][roundId[key]] = timeStamp;
        roundId[key]++;
    }


    function latestAnswer(IPoolManager.PoolKey calldata key) external view returns(uint160) {

        bytes32 pKey = keccak256(abi.encode(key));
        return roundData[pKey][roundId[pKey]];
    }

    function latestTimestamp(IPoolManager.PoolKey calldata key) external view returns(uin256) {

        return latestTimestamp[keccak256(abi.encode(key))];
    }

    function getAnswer(IPoolManager.PoolKey calldata key, 
                        uint256 roundId) 
                        external view returns (uint160){


        return roundData[keccak256(abi.encode(key))][roundId];          

    }

    function latestRound(IPoolManager.PoolKey calldata key) external view returns (uint256){

        return roundId[keccak256(abi.encode(key))];

    }

    function getTimestamp(IPoolManager.PoolKey calldata key, 
                          uint256 roundId) 
                          external view returns (uint256){
        
        return roundIdTimestamp[keccak256(abi.encode(key))][roundId];
    }
}
