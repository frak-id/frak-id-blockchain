// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

/// @author @KONFeature
/// @title IPausable
/// @notice Interface for a pausable contract
/// @custom:security-contact contact@frak.id
interface IPausable {
    /// @dev Pause the contract
    function pause() external;

    /// @dev Unpause the contract
    function unpause() external;
}
