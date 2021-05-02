# FCUL - TI 2020/2021 - Solidity Project

- Bárbara Proença, 55890
- Ivo Oliveira, 50301
- João Loureiro, 46796

## Introduction

This project aims to provide a complete implementation of a Lease smart contract.

The contract can be found in file `lease.sol`

All smart contract code is written in Solidity and is intended to be deployed in the Ethereum blockchain.

## Testing

The contract may be manually deployed in a private network using `truffle` or `web3`.

After being deployed by the Lessor, the contract should be signed by the Insurance Company and the Lessee, using the functions `insuranceSign` and `lesseeSign`, respectively.

At this point, the contract is valid and may be used by the Lessee to pay installments every cycle (via the `pay` function), amortize the residual value (via the `amortize` function) or liquidate the remaining installments (via the `liquidate` function). They may also terminate the contract at any moment by calling the `terminate` function.

The Insurance Company may declare the asset destroyed using the `destroy` function.

All funds transferred to the contract are stored and may be withdrawn by the Lessor at any moment via the `withdraw` function.

## Gas Costs

### Deployment

There are several factors that increase a contract's deployment gas cost:
- Flat fees: the CREATE opcode has a fixed cost of 32000 gas and each transaction, including the one required to deploy the contract, costs 21000 gas.
- Bytecode: the amount of bytes in the compiled contract. Each byte costs 200 gas. Using the Solidity Compiler, we can see that the bytecode size of the Lease contract is 11053 bytes.
- Transaction data: any transaction data sent costs 16 gas for non-zero bytes and 4 gas for zero bytes.
- Constructor code: all code run during contract creation counts towards the deployment gas cost.

The constructor is responsible for creating getters for all public state variables (of which we only have 2).
In the Lease contract, the contructor stores multiple values in state variables.
These storage-related operations are fairly expensive, contributing to the overall high deployment cost of this contract.
For example, an SSTORE opecode assigning a non-zero value to a state variable costs 20000 gas, while an SSTORE operation resetting the variable's value to zero costs 5000 gas.

To lower gas costs, it is good practice to keep the amount of public state variables as low as possible and to have as few storage operations as possible.
However, in the case of this contract, many state variables are required for all functionality to work properly.

Adding all these costs together, the Lease contract would cost around 3 million gas to deploy.

All opcode gas costs above were obtained from the Ethereum Yellow Paper, found here: https://ethereum.github.io/yellowpaper/paper.pdf

### External functions

These functions follow several best practices to lower the gas costs, such as:
- Avoiding unbounded arrays: iterating over these arrays can cost significant amounts of gas and, if unchecked, may even make the function gas cost to go over reasonable transaction gas limits.
- Avoiding unnecessary event emission: only the required `Purchase` and `Destroyed` events are emitted. Events cost 375 gas plus 8 gas for each data byte to emit. Each indexed topic in an event costs 375 gas instead of depending on the size of the data.
- Using the `bytes32` type: using this type for the asset's unique identifier avoids the use of byte arrays and strings. Other data types that require paking are also avoided.
- Using the `require` built-in function: whenever possible, use this function to safeguard against invalid states and arguments instead of `assert`. This reduces gas costs, as the `require` function is essentially free.
- Using internal pure functions: these functions cost extremely low amounts of gas to call and improve code readability.

Some common patterns used in this contract, while improved its security and performance, actually increase the gas cost by adding new functions or function modifiers. For example, the withdrawal pattern requires the creation of a new external function with additional state management besides the 9000 gas `transfer` call.

`insuranceSign` function: this function simply writes to 3 state variables, so it costs around 2400 gas.

`lesseeSign` function: similarly, this function mainly updates state variables, costing around 4800 gas, plus the negligible cost of a few arithmetic operations.

`pay` function: considering the transfer of funds and the possible emission of a `Purchased` event, this function's multiple branches result in a gas cost ranging from around 89700 gas to around 90610 gas.

`amortize` function: this function costs around 40000 gas, as it simply updates 2 of the contract's state variables.

`liquidate` function: this function may also emit the `Purchased` event, costing from around 60000 gas to 89700 gas.

`withdraw` function: transfering funds to an address costs 9700 gas, so this function costs around 29700 gas in total.

`terminate` function: this simple function updates the contract's state and performs some accounting operations, costing around 40000 gas.

`destroy` function: emitting the `Destroyed` event cost 910 gas, so the function costs around 40910 gas.

### Internal functions

All five internal functions (`calculateInstallment`, `calculateInsurance`, `calculateRental`, `calculateResidual` and `getCurrentCycle`) are pure functions.
This means that they cost no gas when called from local code, but cost some gas when called from within other functions that change the contract's state in the context of a transaction.
