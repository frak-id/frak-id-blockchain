// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IListenerBadges.sol";
import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract ListenerBadges is IListenerBadges {
    // Map of user address to listener badge
    mapping(address => uint64) private _listenerBadges;

    function updateListenerBadge(address listener, uint64 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateListenerBadge(address listener, uint64 badge)
        internal
    {
        _listenerBadges[listener] = badge;
        emit ListenerBadgeUpdated(listener, badge);
    }

    /**
     * @dev Update the content internal coefficient
     */
    function _getListenerBadge(address listener)
        internal view returns (uint64 listenerBadge)
    {
                listenerBadge = _listenerBadges[listener];
        if (listenerBadge == 0) {
            // If the badge of this listener isn't set yet, set it to default
            listenerBadge = 1 ether;
        }
        return listenerBadge;
    }

    /**
     * @dev Find the badge for the given listener (on a 1e18 scale)
     */
    function getListenerBadge(address listener) external view override returns (uint64 listenerBadge) {
        return _getListenerBadge(listener);
    }
}
