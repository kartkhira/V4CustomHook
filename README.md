# V4CustomHook

### This repository contains the code for the DynamicOracle contract, which is a custom hook designed for use with Uniswap V4 contracts.
## Setup

To get started, follow these steps:

1. Clone the repository:
```
gh repo clone kartkhira/UnitializedImplementaionVul
```

2. Refactoring:
 Replace the existing `PoolManager.sol` and `PoolId.sol` files with the corresponding files from the Uniswap V4 contracts. This is necessary because the repository with the official Forge installation has compilation issues.


3. Testing:
 Run the tests using Forge:
  ```
  forge test -vvvv
  ```
  
4. Running Separate Tests:
 If you want to run specific tests individually, you can use the following command:
  ```
  forge test --match-contract TestDynamicOracle --match-test testOracleAfterSwap -vvvv
  ```

## Contract Rewrite

The `DynamicOracle`is written to use the Uniswap V4 contracts. The contract is designed as a custom hook for Uniswap V4 and provides functionality for dynamic fee management and price oracles.

### Fee Calculation

The `getFee` function calculates and returns the dynamic fee based on the time elapsed since contract deployment. It uses the block timestamp and a starting fee value to calculate the dynamic fee.

### Oracle Data: 
The contract maintains and updates oracle data, including round data, latest timestamps, and round IDs. It includes functions to retrieve the latest price, timestamp, and specific round data.
