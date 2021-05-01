# FCUL - TI 2020/2021 - Solidity Project

- Bárbara Proença, 55890
- Ivo Oliveira, 50301
- João Loureiro, 46796

## Introduction

This project aims to provide a complete implementation of a Lease smart contract.

The contract can be found in file `contracts/lease.sol`

All smart contract code is written in Solidity and is intended to be deployed in the Ethereum blockchain.

Solidity documentation can be found here: https://docs.soliditylang.org/en/v0.8.4/index.html

## Installation

To install the solidity compiler, run `sudo apt install solc`

To use the Node.js environment to test the contracts, install dependencies by running `npm install`

To check for gas values, run `solc contract.sol --gas` or `npm run gas`

## Testing

The following command compiles the contracts and runs all tests: `npm test`

The contract may also be deployed in a private network manually.

## Gas Costs

Deployment:

### External functions

None of these functions use arrays.

`insuranceSign` function:

`lesseeSign` function:

`pay` function:

`amortize` function:

`liquidate` function:

`withdraw` function:

`terminate` function:

`destroy` function:

### Internal functions

All five internal functions (`calculateInstallment`, `calculateInsurance`, `calculateRental`, `calculateResidual` and `getCurrentCycle`) are pure functions.
This means they cost no gas when called from local code, but cost some gas when called from within other functions that change the contract's state in the context of a transaction.
