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
// To check for gas values, run `solc contract.sol --gas`

// Some runtimes do not support fixed-point numbers
// To overcome this limitation, fixed-point arithmetic may be simulated using a variable representing the decimal precision
// For example, (int * (10 ** precision)) / fixed / (10 ** precision)
// Fine and interest rates are stored as uint8 because no precision is needed and,
// since they are represented as percentages, the maximum percentage value (100) is less than 2^8 = 256

// The free functions below always have implicit internal visibility

/**
 * @notice Calculate the contract's monthly installment, the amount paid monthly by the Lessee for the use of the asset
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _value Value of the asset
 * @param _lifespan Lifespan of the asset, in cycles
 * @return Contract's monthly installment amount
 */
function calculateMonthlyInstallment(uint64 _value, uint32 _lifespan) pure returns (uint64) {
  return _value / _lifespan;
}

/**
 * @notice Calculate the contract's monthly insurance, the amount paid monthly by the Lessee for the asset's insurance
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _value Value of the asset
 * @param _interestRate Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
 * @param _duration Duration of the lease, in cycles
 * @return Contract's monthly insurance amount
 */
function calculateMonthlyInsurance(uint64 _value, uint8 _interestRate, uint32 _duration) pure returns (uint64) {
  // The result is cast to uint64 because the monthly insurance cost must be an integer value
  return uint64((_value * _interestRate) / _duration);
}

/**
 * @notice Calculate the contract's rental value, the total amount paid monthly by the Lessee
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _monthlyInstallment Amount paid monthly by the Lessee for the use of the asset
 * @param _monthlyInsurance Amount paid monthly by the Lessee for the asset's insurance
 * @return Contract's rental amount
 */
function calculateRental(uint64 _monthlyInstallment, uint64 _monthlyInsurance) pure returns (uint64) {
  return _monthlyInstallment + _monthlyInsurance;
}

/**
 * @notice Calculate the contract's residual value, the price the Lessee has to pay at the end of the lease to acquire the asset
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _value Value of the asset
 * @param _monthlyInstallment Amount paid monthly by the Lessee
 * @param _duration Duration of the lease, in cycles
 * @return Contract's current residual value
 */
function calculateResidual(uint64 _value, uint64 _monthlyInstallment, uint32 _duration) pure returns (uint64) {
  return _value - (_monthlyInstallment * _duration);
}

/**
 * @title AbstractLease
 * @notice Abstract lease contract containing Lease type, event, modifier and external function declarations
 */
abstract contract AbstractLease {

  // The current state of the contract, publicly visible (externally readable by other contracts)
  LeaseState public state;

  // Enum containing all possible lease states
  // This structure cannot encode state assignment contraints
  enum LeaseState {
    CREATED,
    SIGNED,
    VALID,
    TERMINATED
  }

  // Events allow clients to subscribe and react to changes
  // Created event, emitted when the contract is created by the Lessor
  event Created(address indexed lessor, bytes32 indexed identifier, uint64 value, uint32 lifespan,
      uint32 periodicity, uint8 fineRate, uint64 terminationFine);
  // Signed event, emitted when the contract is signed by the Insurance Company
  event Signed(address indexed insuranceCompany, uint8 interestRate);
  // Valid event, emitted when the contract is signed by the Lessee
  event Valid(address indexed lessee, uint32 duration);
  // event Terminated();
  // event Purchased();
  // event Destroyed();

  // Custom errors were added in version 0.8.4
  // /**
  //  * @notice Thrown when the current state does not match the required state
  //  * @param currentState Current lease state
  //  * @param requiredState Required lease state
  //  * @param message Error message
  //  */
  // error InvalidStateError(LeaseState currentState, LeaseState requiredState, string message);

  // Ensure that the current lease state is equal to the state required by the function
  modifier ensureState(LeaseState _state, string memory _message) {
    // Guarantee that the state is equal to _state before proceeding
    require(state == _state, _message);
    // A revert statement allows throwing a custom error
    // if (state != _state) revert InvalidStateError({
    //   currentState: state,
    //   requiredState: _state,
    //   message: _message
    // });
    // The following line executes the function
    _;
  }

  // constructor(LeaseState _state) {
  //   // The lease's state is set its initial state
  //   state = _state;
  // }

  // These functions may also be declared in a separate interface
  // Functions declared in interfaces do not require the virtual keyword
  function insuranceSign(uint8 _interestRate) external virtual;
  function lesseeSign(uint32 _duration) external virtual;

}

/**
 * @title Lease
 * @notice The Lease contract
 * @dev Extends abstract contract AbstractLease
 */
contract Lease is AbstractLease {

  // Blockchain address of the Lessor, the owner of the asset
  address payable private lessor;
  // Blockchain address of the Insurance Company
  address payable private insuranceCompany;
  // Blockchain address of the Lessee, the holder of the lease
  // The Lessee does not receive any currency, so the address is stored as non-payable
  address private lessee;

  // Unique identifier of the asset
  bytes32 public immutable identifier;
  // Value of the asset
  uint64 public immutable value;
  // Lifespan of the asset, in cycles
  uint32 public immutable lifespan;
  // Cycle periodicity for rental payments
  uint32 public immutable periodicity;
  // Additional cycle cost if the Lessee fails to pay on a given cycle, expressed as a percentage of the asset's value
  uint8 public immutable fineRate;
  // Amount the Lessee must pay if they terminate the lease before its duration
  uint64 public immutable terminationFine;
  // Amount the insurance company will receive if the lease runs for its whole duration, expressed as a percentage of the asset's value
  uint8 public interestRate;
  // Duration of the lease, in cycles
  uint32 public duration;

  // Contract creation time, as seconds since unix epoch
  uint256 public createdAt;

  // State variables above this line will not be changed after the contract is signed by the Insurance Company and the Lessee

  // The constructor is run only once when the contract is created
  constructor(bytes32 _identifier, uint64 _value, uint32 _lifespan,
      uint32 _periodicity, uint8 _fineRate, uint64 _terminationFine) {
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
  function insuranceSign(uint8 _interestRate) external override ensureState(LeaseState.CREATED, "Lease must be in the Created state.") {
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
  function lesseeSign(uint32 _duration) external override ensureState(LeaseState.SIGNED, "Lease must be in the Signed state.") {
    // The caller of this function is considered the Lessee
    lessee = payable(msg.sender);
    duration = _duration; // e.g. 10
    // The lease's state is set to Valid
    state = LeaseState.VALID;
    // Emit a Valid event, which is stored in the blockchain
    emit Valid(msg.sender, duration);
  }

}
