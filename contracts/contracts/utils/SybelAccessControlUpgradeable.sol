// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IPausable.sol";
import "../utils/SybelRoles.sol";

/// @custom:security-contact crypto-support@sybel.co
abstract contract SybelAccessControlUpgradeable is Initializable, IPausable, AccessControlUpgradeable, UUPSUpgradeable {
    // Is this contract paused ?
    bool private _paused;

    function __SybelAccessControlUpgradeable_init() internal onlyInitializing {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(SybelRoles.ADMIN, msg.sender);
        _grantRole(SybelRoles.PAUSER, msg.sender);
        _grantRole(SybelRoles.UPGRADER, msg.sender);

        // Tell we are not paused at start
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() private view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Pause this smart contract
     */
    function pause() external override whenNotPaused onlyRole(SybelRoles.PAUSER) {
        _paused = true;
    }

    /**
     * @dev Un pause this smart contract
     */
    function unpause() external override whenPaused onlyRole(SybelRoles.PAUSER) {
        _paused = false;
    }

    /**
     * @dev Authorize the upgrade of this contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(SybelRoles.UPGRADER) {}
}
