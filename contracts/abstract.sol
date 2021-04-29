// FCUL - TI 2020/2021
// Barbara Proenca, 55890
// Ivo Oliveira, 50301
// Joao Loureiro, 46796

// SPDX-License-Identifier: UNLICENSED
// Written for solidity version 0.8.0
pragma solidity ^0.8.0;

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
  // Terminated event, emitted when the contract is destroyed by the Lessee
  event Terminated();
  // Purchased event, emitted when the asset is purchased by the Lessee
  event Purchased(string message);
  // Destroyed event, emitted when the asset is destroyed by the Insurance Company
  event Destroyed(string message);

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
    require(state == _state, string(abi.encodePacked("Lease must be in the ", _message, " state.")));
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
    require(msg.sender == sender, "User does not have permission to call this function.");
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

  function pay() external payable virtual;

  function amortize() external payable virtual;

  function liquidate() external payable virtual;

  function withdraw() external virtual;

  function terminate() external payable virtual;

  function destroy() external payable virtual;

}
