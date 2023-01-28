// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IPausable} from "./IPausable.sol";
import {FrakRoles} from "./FrakRoles.sol";
import {NotAuthorized, ContractPaused, ContractNotPaused, RenounceForCallerOnly} from "./FrakErrors.sol";

/// @custom:security-contact contact@frak.id
abstract contract FrakAccessControlUpgradeable is Initializable, ContextUpgradeable, IPausable, UUPSUpgradeable {
    /// Event emitted when contract is paused or unpaused
    event Paused();
    event Unpaused();

    /// Event emitted when roles changes
    event RoleGranted(address indexed account, bytes32 indexed role);
    event RoleRevoked(address indexed account, bytes32 indexed role);

    // Is this contract paused ?
    bool private _paused;

    // Roles to members
    mapping(bytes32 => mapping(address => bool)) private _roles;

    function __FrakAccessControlUpgradeable_init() internal onlyInitializing {
        __Context_init();
        __UUPSUpgradeable_init();

        _grantRole(FrakRoles.ADMIN, _msgSender());
        _grantRole(FrakRoles.PAUSER, _msgSender());
        _grantRole(FrakRoles.UPGRADER, _msgSender());

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
        if (paused()) revert ContractPaused();
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
        if (!paused()) revert ContractNotPaused();
        _;
    }

    /**
     * @dev Pause this smart contract
     */
    function pause() external override whenNotPaused onlyRole(FrakRoles.PAUSER) {
        _paused = true;
        emit Paused();
    }

    /**
     * @dev Un pause this smart contract
     */
    function unpause() external override whenPaused onlyRole(FrakRoles.PAUSER) {
        _paused = false;
        emit Unpaused();
    }

    /**
     * @notice Authorize the upgrade of this contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(FrakRoles.UPGRADER) {}

    /**
     * @notice Ensure the calling user have the right role
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @notice Check that the calling user have the right role
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @notice Check the given user have the role
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) revert NotAuthorized();
    }

    /**
     * @notice Grant the role to the account
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(FrakRoles.ADMIN) {
        _grantRole(role, account);
    }

    /**
     * @notice Grant the role to the account
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(account, role);
        }
    }

    /**
     * @notice Revoke the role to the account
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(FrakRoles.ADMIN) {
        _revokeRole(role, account);
    }

    /**
     * @notice User renounce to the role
     */
    function renounceRole(bytes32 role, address account) public virtual {
        if (account != _msgSender()) revert RenounceForCallerOnly();

        _revokeRole(role, account);
    }

    /**
     * @dev Revoke the given role to the user
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(account, role);
        }
    }

    /**
     * @notice Check if the user has the given role
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role][account];
    }
}
