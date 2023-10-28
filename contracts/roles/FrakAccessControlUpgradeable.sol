// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { Initializable } from "@oz-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@oz-upgradeable/utils/ContextUpgradeable.sol";
import { FrakRoles } from "./FrakRoles.sol";
import { NotAuthorized, RenounceForCallerOnly } from "../utils/FrakErrors.sol";

/**
 * @author @KONFeature
 * @title FrakAccessControlUpgradeable
 * @dev This contract provides an upgradeable access control framework, with roles and pausing functionality.
 *
 * Roles can be granted and revoked by a designated admin role, and certain functions can be restricted to certain roles
 * using the 'onlyRole' modifier. The contract can also be paused, disabling all non-admin functionality.
 *
 * This contract is upgradeable, meaning that it can be replaced with a new implementation, while preserving its state.
 *
 * @custom:security-contact contact@frak.id
 */
abstract contract FrakAccessControlUpgradeable is Initializable, ContextUpgradeable, UUPSUpgradeable {
    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("NotAuthorized()")))'
    uint256 private constant _NOT_AUTHORIZED_SELECTOR = 0xea8e4eb5;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a role is granted
    event RoleGranted(address indexed account, bytes32 indexed role);
    /// @dev Event emitted when a role is revoked
    event RoleRevoked(address indexed account, bytes32 indexed role);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Is this contract currently paused ?
    /// @dev Unused now, since pausim mecanism isn't here anymore, can be reused
    bool private _paused;

    /// @dev Mapping of roles -> user -> hasTheRight
    mapping(bytes32 roles => mapping(address user => bool isAllowed)) private _roles;

    /// @dev Initialise the contract and also grant the role to the msg sender
    function __FrakAccessControlUpgradeable_init() internal onlyInitializing {
        __Context_init();
        __UUPSUpgradeable_init();

        _grantRole(FrakRoles.ADMIN, msg.sender);
        _grantRole(FrakRoles.UPGRADER, msg.sender);

        // Tell we are not paused at start
        _paused = false;
    }

    /// @dev Initialise the contract and also grant the role to the msg sender
    function __FrakAccessControlUpgradeable_Minter_init() internal onlyInitializing {
        __FrakAccessControlUpgradeable_init();

        _grantRole(FrakRoles.MINTER, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant the `role` to the `account`
    function grantRole(bytes32 role, address account) external onlyRole(FrakRoles.ADMIN) {
        _grantRole(role, account);
    }

    /// @dev Revoke the `role` to the `account`
    function revokeRole(bytes32 role, address account) external onlyRole(FrakRoles.ADMIN) {
        _revokeRole(role, account);
    }

    /// @dev `Account` renounce to the `role`
    function renounceRole(bytes32 role, address account) external {
        if (account != msg.sender) revert RenounceForCallerOnly();

        _revokeRole(role, account);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the user has the given role
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant the `role` to the `account`
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(account, role);
        }
    }

    /// @dev Revoke the given `role` to the `account`
    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(account, role);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Check that the calling user have the right `role`
    function _checkRole(bytes32 role) private view {
        address sender = msg.sender;
        assembly {
            // Kecak (role, _roles.slot)
            mstore(0, role)
            mstore(0x20, _roles.slot)
            let roleSlote := keccak256(0, 0x40)
            // Kecak (acount, roleSlot)
            mstore(0, sender)
            mstore(0x20, roleSlote)
            let slot := keccak256(0, 0x40)

            // Get var at the given slot
            let hasTheRole := sload(slot)

            // Ensre the user has the right roles
            if eq(hasTheRole, false) {
                mstore(0x00, _NOT_AUTHORIZED_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Ensure the calling user have the right role
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @notice Authorize the upgrade of this contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(FrakRoles.UPGRADER) { }
}
