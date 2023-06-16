forge test --match-contract TestDynamicOracle --match-test testOracleAfterSwap -vvvv

# V4CustomHook

###
1. Setup
```
gh repo clone kartkhira/UnitializedImplementaionVul
```

2. Refactoring
```
Replace PoolManager.sol and PoolId.sol with v4-contracts at https://github.com/Uniswap/v4-core

```
3. Testing
```
forge test -vvvv
```
4. RunningSeprate Tests
```
forge test --match-contract TestDynamicOracle --match-test testOracleAfterSwap -vvvv
```