// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/lease.sol";

contract LeaseTest {

  // Lease leaseInstance;

  // function beforeAll () public {
  //   leaseInstance = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
  // }

  // function checkWinningProposal () public {
  //   ballotToTest.vote(0);
  //   Assert.equal(ballotToTest.winningProposal(), uint(0), "proposal at index 0 should be the winning proposal");
  //   Assert.equal(ballotToTest.winnerName(), bytes32("candidate1"), "candidate1 should be the winner name");
  // }

  // function checkWinninProposalWithReturnValue () public view returns (bool) {
  //   return ballotToTest.winningProposal() == 0;
  // }

  function checkNewContract () public {
    Lease lease = new Lease("id", 100 wei, 10, 3 minutes, 5, 10 wei);
    assert(lease.identifier() == "id");
  }

}
