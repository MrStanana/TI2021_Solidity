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

// Some runtimes do not support fixed-point numbers
// To overcome this limitation, fixed-point arithmetic may be simulated using a variable representing the decimal precision
// For example, (int * (10 ** precision)) / fixed / (10 ** precision)
// Fine and interest rates are stored as uint32 because no precision is needed

/**
 * @title Lease
 * @notice The Lease contract
 */
contract Lease {

  // Enum containing all possible lease states
  // This structure cannot encode state assignment contraints
  enum LeaseState {
    CREATED,
    SIGNED,
    VALID,
    TERMINATED
  }

  // Events allow clients to subscribe and react to changes
  // Purchased event, emitted when the asset is purchased by the Lessee
  event Purchased(bytes32 indexed identifier, address lessee);
  // Destroyed event, emitted when the asset is destroyed by the Insurance Company
  event Destroyed(bytes32 indexed identifier, address insuranceCompany);

  // Custom errors were added in version 0.8.4
  // /**
  //  * @notice Thrown when the current state does not match the required state
  //  * @param currentState Current lease state
  //  * @param requiredState Required lease state
  //  * @param message Error message
  //  */
  // error InvalidStateError(LeaseState currentState, LeaseState requiredState, string message);

  // Ensure that the current lease state is equal to the state required by the function
  modifier ensureState(LeaseState _state) {
    // Guarantee that the state is equal to _state before proceeding
    require(state == _state, "Lease must be in the correct state");
    // require(state == _state, string(abi.encodePacked("Lease must be in the ", _message, " state.")));
    // A revert statement allows throwing a custom error
    // if (state != _state) revert InvalidStateError({
    //   currentState: state,
    //   requiredState: _state,
    //   message: _message
    // });
    // The following line executes the function
    _;
  }

  // Ensure that the caller is equal to the address required by the function
  modifier ensureCaller(address sender) {
    // Guarantee that the funcion caller is allowed to call the function before proceeding
    require(msg.sender == sender, "User does not have permission to call this function");
    // The following line executes the function
    _;
  }

  // The current state of the contract, publicly visible (externally readable by other contracts)
  LeaseState public state;

  // The lessor attribute may be marked as immutable, because it is assigned to in the contructor
  // Blockchain address of the Lessor, the owner of the asset
  address payable private lessor;
  // Blockchain address of the Insurance Company
  address payable private insuranceCompany;
  // Blockchain address of the Lessee, the holder of the lease
  // The Lessee does not receive any currency, so the address is stored as non-payable
  address private lessee;

  // Unique identifier of the asset
  bytes32 public identifier;
  // Value of the asset
  uint256 private value;
  // Lifespan of the asset, in cycles
  uint32 private lifespan;
  // Cycle periodicity for rental payments
  uint256 private periodicity;
  // Additional cycle cost if the Lessee fails to pay on a given cycle, expressed as a percentage of the asset's value
  uint32 private fineRate;
  // Amount the Lessee must pay if they terminate the lease before its duration
  uint256 private terminationFine;
  // Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
  uint32 private interestRate;
  // Duration of the lease, in cycles
  uint32 private duration;

  // Contract signing time, as seconds since unix epoch
  uint256 private signedAt;

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
    identifier = _identifier; // e.g. sha256(abi.encode(keccak256(nonce)))
    value = _value; // e.g. 10 wei, 0.1 ether
    lifespan = _lifespan; // e.g. 10
    periodicity = _periodicity; // e.g. 4 weeks, 3 minutes
    fineRate = _fineRate; // e.g. 0.1
    terminationFine = _terminationFine; // e.g. 10 wei, 0.1 ether
    available = 0;
    totalPaid = 0;
    lastPaidCycle = 0;
    installment = calculateInstallment(value, lifespan);
    remainingResidual = calculateResidual(value, installment, duration);
    // The lease's state is set to Created
    state = LeaseState.CREATED;
  }

  /**
   * @notice Called by the Insurance Company, to sign the contract
   * @param _interestRate Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
   */
  function insuranceSign(uint8 _interestRate) external ensureState(LeaseState.CREATED) {
    // The caller of this function is considered the Insurance Company
    insuranceCompany = payable(msg.sender);
    interestRate = _interestRate; // e.g. 0.1
    // The lease's state is set to Signed
    state = LeaseState.SIGNED;
  }

  /**
   * @notice Called by the Lessee, to sign the contract
   * @param _duration Duration of the lease, in cycles
   */
  function lesseeSign(uint32 _duration) external ensureState(LeaseState.SIGNED) {
    // Guarantee the duration does not exceed to asset's lifespan
    require(_duration <= lifespan, "Lease duration must not exceed asset lifespan");
    // The caller of this function is considered the Lessee
    lessee = payable(msg.sender);
    duration = _duration; // e.g. 10
    // Set the contract's signing time
    signedAt = block.timestamp;
    insurance = calculateInsurance(value, interestRate, duration);
    rental = calculateRental(installment, insurance);
    // The lease's state is set to Valid
    state = LeaseState.VALID;
  }

  // Separating the `pay`, `amortize` and `liquidate` functions simplifies the logic that implements the business rules
  // The `pay` and `amortize` functions must be reentrancy safe because they may not change the contract's state
  // This means that they must guard against being recursively called from within another contract's code
  // Because these functions do not call functions from other contracts nor transfer any funds, no extra measures need to be taken
  /**
   * @notice Called by the Lessee to pay the installments
   */
  function pay() external payable ensureCaller(lessee) ensureState(LeaseState.VALID) {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated");
    require(currentCycle > lastPaidCycle, "Cycle has already been paid");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2, "Contract has terminated due to lack of payment");
    bool purchase;
    if (currentCycle == lastPaidCycle + 1) {
      purchase = currentCycle == duration && (msg.value == rental + remainingResidual);
      require(msg.value == rental, "Must pay the full installment exactly");
      lastPaidCycle = currentCycle;
      // Store the transferred value as funds available for withdrawal
      available += installment;
      // This direct transfer is reentrancy safe, because the state guards above prevent recursion
      insuranceCompany.transfer(insurance);
    } else { // currentCycle == lastPaidCycle + 2
      purchase = currentCycle == duration && (msg.value == 2 * rental + (rental * fineRate / 100) + remainingResidual);
      require(msg.value == 2 * rental + (rental * fineRate / 100), "Must pay the full installments exactly, plus the fine");
      lastPaidCycle = currentCycle;
      // Store the transferred value as funds available for withdrawal
      available += 2 * installment;
      insuranceCompany.transfer(2 * insurance);
    }
    if (lastPaidCycle == duration) {
      // The lease's state is set to Terminated
      state = LeaseState.TERMINATED;
      remainingResidual = 0;
      if (purchase) {
        // Emit a Purchased event
        emit Purchased(identifier, lessee);
      }
    }
  }

  /**
   * @notice Called by the Lessee to amortize the residual value
   */
  function amortize() external payable ensureCaller(lessee) ensureState(LeaseState.VALID) {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2, "Contract has terminated due to lack of payment");
    // Guarantee that transferred value is lower than the remaining residual value
    require(msg.value <= remainingResidual, "The amortized value must be lower than the remaining residual value");
    // Subtract the transferred value from the remaining residual value
    remainingResidual -= msg.value;
    // Store the transferred value as funds available for withdrawal
    available += msg.value;
  }

  /**
   * @notice Called by the Lessee to liquidate the lease by paying all the remaining installments at once (without paying the insurance)
   */
  function liquidate() external payable ensureCaller(lessee) ensureState(LeaseState.VALID) {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    require(currentCycle <= duration, "Contract is already terminated");
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2, "Contract has terminated due to lack of payment");
    uint256 remainingCycles = duration - lastPaidCycle;
    bool purchase = msg.value == remainingCycles * installment + remainingResidual;
    require(purchase || msg.value == remainingCycles * installment);
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
    // Store the transferred value as funds available for withdrawal
    available += msg.value;
    lastPaidCycle = duration;
    if (purchase) {
      remainingResidual = 0;
      // Emit a Purchased event
      emit Purchased(identifier, lessee);
    }
  }

  // The `withdraw` function implements the withdrawal pattern
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
  function withdraw() external ensureCaller(lessor) {
    // Guarantee that there are funds available for withdrawal
    require(available != 0, "No amount available for withdrawal");
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
  function terminate() external payable ensureCaller(lessee) ensureState(LeaseState.VALID) {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2, "Contract has terminated due to lack of payment");
    if (currentCycle <= 1) {
      // If terminating within the first cycle, the Lessee pays no fine
      require(msg.value == 0, "No fine on the first cycle");
    } else {
      // If terminating after the first cycle, the Lessee must pay the initially agreed termination fine
      require(msg.value == terminationFine, "Termination after the first cycle incurs in a termination fine");
      // Store the transferred value as funds available for withdrawal
      available += msg.value;
    }
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
  }

  /**
   * @notice Called by the Insurance Company to declare the asset destroyed
   */
  function destroy() external payable ensureCaller(insuranceCompany) ensureState(LeaseState.VALID) {
    uint256 currentCycle = getCurrentCycle(signedAt, periodicity, block.timestamp);
    // Revert and refund if the contract was terminated for lack of payment
    require(currentCycle <= lastPaidCycle + 2, "Contract has terminated due to lack of payment");
    // Guarantee that the Insurance Company pays the value of the asset before destroying it
    require(msg.value == value, "Must pay the value of the asset");
    // The lease's state is set to Terminated
    state = LeaseState.TERMINATED;
    // Store the transferred value as funds available for withdrawal
    available += msg.value;
    // Emit a Destroyed event
    emit Destroyed(identifier, insuranceCompany);
  }

  /**
   * @notice Calculate the contract's installment per cycle, the amount paid per cycle by the Lessee for the use of the asset
   * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
   * @param _value Value of the asset
   * @param _lifespan Lifespan of the asset, in cycles
   * @return Contract's installment amount per cycle
   */
  function calculateInstallment(uint256 _value, uint32 _lifespan) internal pure returns (uint256) {
    return _value / _lifespan;
  }

  /**
   * @notice Calculate the contract's insurance cost per cycle, the amount paid per cycle by the Lessee for the asset's insurance
   * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
   * @param _value Value of the asset
   * @param _interestRate Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
   * @param _duration Duration of the lease, in cycles
   * @return Contract's insurance amount per cycle
   */
  function calculateInsurance(uint256 _value, uint32 _interestRate, uint32 _duration) internal pure returns (uint256) {
    // The insurance cost per cycle must be an integer value, so there may be some error in the final result
    return (_value * _interestRate) / (100 * _duration);
  }

  /**
   * @notice Calculate the contract's rental value, the total amount paid per cycle by the Lessee
   * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
   * @param _installment Amount paid per cycle  by the Lessee for the use of the asset
   * @param _insurance Amount paid per cycle by the Lessee for the asset's insurance
   * @return Contract's rental amount per cycle
   */
  function calculateRental(uint256 _installment, uint256 _insurance) internal pure returns (uint256) {
    return _installment + _insurance;
  }

  /**
   * @notice Calculate the contract's residual value, the price the Lessee has to pay at the end of the lease to acquire the asset
   * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
   * @param _value Value of the asset
   * @param _installment Amount paid per cycle by the Lessee
   * @param _duration Duration of the lease, in cycles
   * @return Contract's current residual value
   */
  function calculateResidual(uint256 _value, uint256 _installment, uint32 _duration) internal pure returns (uint256) {
    return _value - (_installment * _duration);
  }

  /**
   * @notice Calculate the current lease cycle
   * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
   * @param _initialTime Timestamp at contract creation
   * @param _periodicity Contract periodicity
   * @param _currentTime Current timestamp
   * @return Current lease cycle
   */
  function getCurrentCycle(uint256 _initialTime, uint256 _periodicity, uint256 _currentTime) internal pure returns (uint256) {
    return ((_currentTime - _initialTime) - 1) / _periodicity + 1;
  }

}
