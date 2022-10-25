// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract ListenerBadges {
    event ListenerBadgeUpdated(address indexed listener, uint64 badge);

    // Map of user address to listener badge
    mapping(address => uint64) private _listenerBadges;

    function updateListenerBadge(address listener, uint64 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateListenerBadge(address listener, uint64 badge) internal {
        _listenerBadges[listener] = badge;
        emit ListenerBadgeUpdated(listener, badge);
    }

    /**
     * @dev Update the content internal coefficient
     */
    function getListenerBadge(address listener) public view returns (uint64 listenerBadge) {
        listenerBadge = _listenerBadges[listener];
        if (listenerBadge == 0) {
            // If the badge of this listener isn't set yet, set it to default
            listenerBadge = 1 ether;
        }
        return listenerBadge;
    }
}
