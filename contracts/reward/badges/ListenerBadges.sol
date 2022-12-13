// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../../utils/FrakMath.sol";
import "../../utils/FrakRoles.sol";
import "../../utils/FrakAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
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
        listenerBadge = _listenerBadges[listener];
        if (listenerBadge == 0) {
            // If the badge of this listener isn't set yet, set it to default
            listenerBadge = 1 ether;
        }
        return listenerBadge;
    }
}
