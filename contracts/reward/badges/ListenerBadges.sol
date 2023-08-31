// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { BadgeTooLarge } from "../../utils/FrakErrors.sol";

/**
 * @author  @KONFeature
 * @title   ListenerBadges
 * @dev Abstract contract for managing the listener badge use as multiplier for earnings.
 * @notice This contract contains methods and variables for initializing, updating, and getting the listener badges.
 * @custom:security-contact contact@frak.id
 */
abstract contract ListenerBadges {
    /// @dev Max badge possible for the content
    uint256 private constant MAX_LISTENER_BADGE = 1000 ether;

    /// @dev Event emitted when a badge is updated
    event ListenerBadgeUpdated(address indexed listener, uint256 badge);

    /// @dev Mapping of listener to their badge
    mapping(address => uint256) private _listenerBadges;

    /// @dev external function used to update the content badges
    function updateListenerBadge(address listener, uint256 badge) external virtual;

    /// @dev Update the 'listener' badge to 'badge'
    function _updateListenerBadge(address listener, uint256 badge) internal {
        if (badge > MAX_LISTENER_BADGE) revert BadgeTooLarge();
        _listenerBadges[listener] = badge;
        emit ListenerBadgeUpdated(listener, badge);
    }

    /// @dev Get the current 'listener' badge
    function getListenerBadge(address listener) public view returns (uint256 listenerBadge) {
        assembly {
            // Get the current listener badge
            // Kecak (listener, _listenerBadges.slot)
            mstore(0, listener)
            mstore(0x20, _listenerBadges.slot)
            // Load it
            listenerBadge := sload(keccak256(0, 0x40))
            // If null, set it to 1 ether by default
            if iszero(listenerBadge) { listenerBadge := 1000000000000000000 }
        }
    }
}
