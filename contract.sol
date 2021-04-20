// SPDX-License-Identifier: UNLICENSED
// written for solidity version 0.8.0
pragma solidity ^0.8.0;
// solidity follows semantic versioning
// we can use `^` to indicate that the code is compatible with any patch from version 0.8

// to install the solidity compiler, run `sudo apt install solc`
// to check for gas values, run `solc contract.sol --gas`

// The contract itself
contract Lease {
  enum LeaseState {
    CREATED,
    SIGNED,
    VALID,
    TERMINATED
  }

  // This represents the state of the contract
  // The state is publicly visible to anyone
  LeaseState public state;

  address payable private lessor;
  address payable private insuranceCompany;

  // The constructor is run only once when the contract is created
  constructor() {
    state = LeaseState.CREATED;
    lessor = payable(msg.sender);
  }

  function insuranceSign() private {
    require(state == LeaseState.CREATED);
    insuranceCompany = payable(msg.sender);
    // TODO: sign
    state = LeaseState.SIGNED;
  }
}
