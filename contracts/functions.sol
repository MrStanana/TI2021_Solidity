// FCUL - TI 2020/2021
// Barbara Proenca, 55890
// Ivo Oliveira, 50301
// Joao Loureiro, 46796

// SPDX-License-Identifier: UNLICENSED
// Written for solidity version 0.8.0
pragma solidity ^0.8.0;

// The free functions below always have implicit internal visibility

/**
 * @notice Calculate the contract's installment per cycle, the amount paid per cycle by the Lessee for the use of the asset
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _value Value of the asset
 * @param _lifespan Lifespan of the asset, in cycles
 * @return Contract's installment amount per cycle
 */
function calculateInstallment(uint256 _value, uint32 _lifespan) pure returns (uint256) {
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
function calculateInsurance(uint256 _value, uint8 _interestRate, uint32 _duration) pure returns (uint256) {
  // The insurance cost per cycle must be an integer value, so there may be some error in the final result
  return (_value * _interestRate) / _duration;
}

/**
 * @notice Calculate the contract's rental value, the total amount paid per cycle by the Lessee
 * @dev This function does not read from or write to state variables (pure) and is only visible within this contract (internal)
 * @param _installment Amount paid per cycle  by the Lessee for the use of the asset
 * @param _insurance Amount paid per cycle by the Lessee for the asset's insurance
 * @return Contract's rental amount per cycle
 */
function calculateRental(uint256 _installment, uint256 _insurance) pure returns (uint256) {
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
function calculateResidual(uint256 _value, uint256 _installment, uint32 _duration) pure returns (uint256) {
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
function getCurrentCycle(uint256 _initialTime, uint256 _periodicity, uint256 _currentTime) pure returns (uint256) {
  return ((_currentTime - _initialTime) - 1) / _periodicity + 1;
}
