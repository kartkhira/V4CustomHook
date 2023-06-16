forge test --match-contract TestDynamicOracle --match-test testOracleAfterSwap -vvvv
forge test -vvvv

# Hook using dynamic fees and acting as oracle

### Please note that selfdestruct is not supported by foundry causing verfication issues. 

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

