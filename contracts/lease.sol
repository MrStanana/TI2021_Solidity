// FCUL - TI 2020/2021
// Barbara Proenca, 55890
// Ivo Oliveira, 50301
// Joao Loureiro, 46796

// SPDX-License-Identifier: UNLICENSED
// Written for solidity version 0.8.0
pragma solidity ^0.8.0;
// Solidity follows semantic versioning
// We can use `^` to indicate that the code is compatible with any patch from minor version 0.8

// Solidity documentation can be found here: https://docs.soliditylang.org/en/v0.8.4/index.html
// To install the solidity compiler, run `sudo apt install solc`
// To check for gas values, run `solc contracts/lease.sol --gas`

// Import AbstractLease contract
import "./abstract.sol";
// Import free functions
import "./functions.sol";

// Some runtimes do not support fixed-point numbers
// To overcome this limitation, fixed-point arithmetic may be simulated using a variable representing the decimal precision
// For example, (int * (10 ** precision)) / fixed / (10 ** precision)
// Fine and interest rates are stored as uint8 because no precision is needed and,
// since they are represented as percentages, the maximum percentage value (100) is less than 2^8 = 256

/**
 * @title Lease
 * @notice The Lease contract
 * @dev Extends abstract contract AbstractLease
 */
contract Lease is AbstractLease {

  // Blockchain address of the Lessor, the owner of the asset
  address payable private immutable lessor;
  // Blockchain address of the Insurance Company
  address payable private insuranceCompany;
  // Blockchain address of the Lessee, the holder of the lease
  // The Lessee does not receive any currency, so the address is stored as non-payable
  address private lessee;

  // Unique identifier of the asset
  bytes32 public immutable identifier;
  // Value of the asset
  uint256 public value;
  // Lifespan of the asset, in cycles
  uint32 public lifespan;
  // Cycle periodicity for rental payments
  uint256 public periodicity;
  // Additional cycle cost if the Lessee fails to pay on a given cycle, expressed as a percentage of the asset's value
  uint8 public fineRate;
  // Amount the Lessee must pay if they terminate the lease before its duration
  uint256 public terminationFine;
  // Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
  uint8 public interestRate;
  // Duration of the lease, in cycles
  uint32 public duration;

  // Contract creation time, as seconds since unix epoch
  uint256 public createdAt;
  // Contract signing time, as seconds since unix epoch
  uint256 public signedAt;

  // State variables to increase performance
  uint256 private installment;
  uint256 private insurance;
  uint256 private rental;

  // State variables above this line will not be changed after the contract is signed by the Insurance Company and the Lessee

  // Funds currently available for withdrawal by the Lessor
  uint256 private available;
  // Total amount paid by the Lessee
  uint256 private totalPaid;
  // Last cycle paid by the Lessee
  uint256 private lastPaidCycle;
  // Remaining residual amount not yet paid by the Lessee
  uint256 private remainingResidual;

  // The constructor is run only once when the contract is created
  constructor(bytes32 _identifier, uint64 _value, uint32 _lifespan, uint32 _periodicity, uint8 _fineRate, uint64 _terminationFine) {
    // The creator of this instance of the contract is considered the Lessor
    lessor = payable(msg.sender); // e.g. 0x5B38Da6a701c568545dCfcB03FcB875f56beddC5
    // The following state variables are immutable and must be assigned in the constructor
    identifier = _identifier; // e.g. sha256(abi.encode(keccak256(nonce)))
    value = _value; // e.g. 10 wei, 0.1 ether
    lifespan = _lifespan; // e.g. 10
    periodicity = _periodicity; // e.g. 4 weeks, 3 minutes
    fineRate = _fineRate; // e.g. 0.1
    terminationFine = _terminationFine; // e.g. 10 wei, 0.1 ether
    // Set the contract's creation time
    createdAt = block.timestamp;
    available = 0;
    totalPaid = 0;
    lastPaidCycle = 0;
    remainingResidual = calculateResidual(value, calculateInstallment(value, lifespan), duration);
    // The lease's state is set to Created
    state = LeaseState.CREATED;
    // Emit a Created event, which is stored in the blockchain
    // Immutable state variables cannot be read at creation time
    emit Created(msg.sender, _identifier, _value, _lifespan, _periodicity, _fineRate, _terminationFine);
  }

  /**
   * @notice Called by the Insurance Company, to sign the contract
   * @param _interestRate Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
   */
  function insuranceSign(uint8 _interestRate) external override ensureState(LeaseState.CREATED, "Created") {
    // The caller of this function is considered the Insurance Company
    insuranceCompany = payable(msg.sender);
    interestRate = _interestRate; // e.g. 0.1
    // The lease's state is set to Signed
    state = LeaseState.SIGNED;
    // Emit a Signed event, which is stored in the blockchain
    emit Signed(msg.sender, interestRate);
  }

  /**
   * @notice Called by the Lessee, to sign the contract
   * @param _duration Duration of the lease, in cycles
   */
  function lesseeSign(uint32 _duration) external override ensureState(LeaseState.SIGNED, "Signed") {
    // Guarantee the duration does not exceed to asset's lifespan
    require(_duration <= lifespan, "Lease duration must not exceed asset lifespan.");
    // The caller of this function is considered the Lessee
    lessee = payable(msg.sender);
    duration = _duration; // e.g. 10
    // Set the contract's signing time
    signedAt = block.timestamp;
    installment = calculateInstallment(value, lifespan);
    insurance = calculateInsurance(value, interestRate, duration);
    rental = calculateRental(installment, insurance);
    // The lease's state is set to Valid
    state = LeaseState.VALID;
    // Emit a Valid event, which is stored in the blockchain
    emit Valid(msg.sender, duration);
  }

  // Separating the `pay`, `amortize` and `liquidate` functions simplifies the logic that implements the business rules
  // The `pay` and `amortize` functions must be reentrancy safe because they may not change the contract's state
  // This means that they must guard against being recursively called from within another contract's code
  // Because these functions do not call functions from other contracts nor transfer any funds, no extra measures need to be taken
  /**
   * @notice Called by the Lessee to pay the installments
   */
  function pay() external payable override ensureCaller(lessee) ensureState(LeaseState.VALID, "Valid") {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated.");
    require(currentCycle > lastPaidCycle, "Cycle has already been paid.");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2);
    bool purchase;
    if (currentCycle == lastPaidCycle + 1) {
      purchase = currentCycle == duration && (msg.value == rental + remainingResidual);
      require(msg.value == rental, "Must pay the full installment exactly.");
      lastPaidCycle = currentCycle;
      // Store the transfered value as funds available for withdrawal
      available += installment;
      // This direct transfer is reentrancy safe, because the state guards above prevent recursion
      insuranceCompany.transfer(insurance);
    } else { // currentCycle == lastPaidCycle + 2
      purchase = currentCycle == duration && (msg.value == 2 * rental + (rental * fineRate / 100) + remainingResidual);
      require(msg.value == 2 * rental + (rental * fineRate / 100), "Must pay the full installments exactly, plus the fine.");
      lastPaidCycle = currentCycle;
      // Store the transfered value as funds available for withdrawal
      available += 2 * installment;
      insuranceCompany.transfer(2 * insurance);
    }
    if (lastPaidCycle == duration) {
      // The lease's state is set to Terminated
      state = LeaseState.TERMINATED;
      if (purchase) {
        // Emit a Purchased event
        emit Purchased(string(abi.encodePacked("Lessee ", lessee, " is the new owner of the asset ", identifier)));
      }
    }
  }

  /**
   * @notice Called by the Lessee to amortize the residual value
   */
  function amortize() external payable override ensureCaller(lessee) ensureState(LeaseState.VALID, "Valid") {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated.");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2);
    // Guarantee that transfered value is lower than the remaining residual value
    require(msg.value <= remainingResidual, "The amortized value must be lower than the remaining residual value.");
    // Subtract the transfered value from the remaining residual value
    remainingResidual -= msg.value;
    // Store the transfered value as funds available for withdrawal
    available += msg.value;
  }

  /**
   * @notice Called by the Lessee to liquidate the lease by paying all the remaining installments at once (without paying the insurance)
   */
  function liquidate() external payable override ensureCaller(lessee) ensureState(LeaseState.VALID, "Valid") {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated.");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2);
    uint256 remainingCycles = duration - lastPaidCycle;
    bool purchase = msg.value == remainingCycles * installment + remainingResidual;
    require(msg.value == remainingCycles * installment || purchase);
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
    // Store the transfered value as funds available for withdrawal
    available += msg.value;
    lastPaidCycle = duration;
    if (purchase) {
      remainingResidual = 0;
      // Emit a Purchased event
      emit Purchased(string(abi.encodePacked("Lessee ", lessee, " is the new owner of the asset ", identifier)));
    }
  }

  // The `withdraw` function implements the withdawal pattern
  // This pattern prevents contracts from becoming stuck in an irrecoverable state if an attacker
  // interacts with the contract using another contract
  // This is because contracts' default fallback functions are non-payable, which means that when we try to
  // transfer funds to contracts without a payable fallback function, the transfer will be refused
  // and the original function will be reverted
  // Also, withdrawal transaction gas costs are paid by the Lessor
  /**
   * @notice Called by the Lessor to withdraw any available funds
   * @dev This function may be called at any time
   */
  function withdraw() external override ensureCaller(lessor) {
    // Guarantee that there are funds available for withdrawal
    require(available != 0, "No amount available for withdrawal.");
    // To make the funtion reentrance safe, the available amount is reset before the transfer
    uint256 amount = available;
    // Reset the available amount
    available = 0 wei;
    // Transfer the available funds to the Lessor, as requested
    lessor.transfer(amount);
  }

  /**
   * @notice Called by the Lessee to terminate the contract
   */
  function terminate() external payable override ensureCaller(lessee) ensureState(LeaseState.VALID, "Valid") {
    if (getCurrentCycle(signedAt, periodicity, block.timestamp) <= 1) {
      // If terminating within the first cycle, the Lessee pays no fine
      require(msg.value == 0, "No fine on the first cycle.");
    } else {
      // If terminating after the first cycle, the Lessee must pay the initially agreed termination fine
      require(msg.value == terminationFine, "Termination after the first cycle incurs in a termination fine.");
    }
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
    // Emit a Terminated event
    emit Terminated();
  }

  /**
   * @notice Called by the Insurance Company to declare the asset destroyed
   */
  function destroy() external payable override ensureCaller(insuranceCompany) ensureState(LeaseState.VALID, "Valid") {
    // Guarantee that the Insurance Company pays the value of the asset before destroying it
    require(msg.value == value, "Must pay the value of the asset.");
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
    // Store the transfered value as funds available for withdrawal
    available += msg.value;
    // Emit a Destroyed event
    emit Destroyed(string(abi.encodePacked("Asset ", identifier, " has been destroyed by the Insurance Company ", insuranceCompany)));
  }

}
