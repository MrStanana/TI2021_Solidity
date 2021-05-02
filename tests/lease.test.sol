// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
// import "truffle/DeployedAddresses.sol";

import "../contracts/lease.sol";

contract LeaseTest {

  uint public initialBalance = 1 ether;

  // Lease lease;

  // function beforeAll () public {
  //   lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
  // }

  // function checkWinningProposal () public {
  //   ballotToTest.vote(0);
  //   Assert.equal(ballotToTest.winningProposal(), uint(0), "proposal at index 0 should be the winning proposal");
  //   Assert.equal(ballotToTest.winnerName(), bytes32("candidate1"), "candidate1 should be the winner name");
  // }

  // function checkWinninProposalWithReturnValue () public view returns (bool) {
  //   return ballotToTest.winningProposal() == 0;
  // }

  // function testDeployedContract() public {
  //   Lease lease = Lease(DeployedAddresses.Lease());
  //   Assert.equal(lease.identifier(), "id", "Invalid identifier");
  // }

  // function testThrowFunctions() public {
  //   bool r;
  //   // We're basically calling our contract externally with a raw call, forwarding all available gas, with
  //   // msg.data equal to the throwing function selector that we want to be sure throws and using only the boolean
  //   // value associated with the message call's success
  //   (r, ) = address(this).call(abi.encodePacked(this.IThrow1.selector));
  //   Assert.isFalse(r, "If this is true, something is broken!");
  //   (r, ) = address(this).call(abi.encodePacked(this.IThrow2.selector));
  //   Assert.isFalse(r, "What?! 1 is equal to 10?");
  // }

  function testNewContract() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    Assert.equal(lease.identifier(), "id", "Invalid identifier");
  }

  function testInsuranceSign() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
  }

  function testLesseeSign() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
  }

  function testPay() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.pay{ value: 12 wei }();
  }

  function testAmortize() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.amortize{ value: 1 wei }();
  }

  function testLiquidate() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.liquidate{ value: 20 wei }();
  }

  function testLiquidateAndPurchase() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.liquidate{ value: 100 wei }();
  }

  function testWithdraw() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.amortize{ value: 1 wei }();
    lease.withdraw();
  }

  function testTerminate() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.terminate();
  }

  function testDestroy() public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    lease.insuranceSign(10);
    lease.lesseeSign(2);
    lease.destroy{ value: 100 wei }();
  }

}
