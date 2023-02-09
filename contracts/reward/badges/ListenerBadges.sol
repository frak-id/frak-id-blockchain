// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {BadgeTooLarge} from "../../utils/FrakErrors.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact contact@frak.id
abstract contract ListenerBadges {
    uint256 private constant MAX_LISTENER_BADGE = 1_000 ether; // Max badge possible for the listener

    // Map of user address to listener badge
    mapping(address => uint256) private _listenerBadges;

    event ListenerBadgeUpdated(address indexed listener, uint256 badge);

    function updateListenerBadge(address listener, uint256 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateListenerBadge(address listener, uint256 badge) internal {
        if (badge > MAX_LISTENER_BADGE) revert BadgeTooLarge();
        _listenerBadges[listener] = badge;
        emit ListenerBadgeUpdated(listener, badge);
    }

    /**
     * @dev Update the content internal coefficient
     */
    function getListenerBadge(address listener) public view returns (uint256 listenerBadge) {
        assembly {
            // Get the current listener badge
            // Kecak (listener, _listenerBadges.slot)
            mstore(0, listener)
            mstore(0x20, _listenerBadges.slot)
            let badgeSlot := keccak256(0, 0x40)
            // Load it
            listenerBadge := sload(badgeSlot)
            // If null, set it to 1 ether by default
            if iszero(listenerBadge) { listenerBadge := 1000000000000000000 }
        }
    }
}
