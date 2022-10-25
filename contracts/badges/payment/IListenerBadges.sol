// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/IPausable.sol";

/**
 * @dev Represent our lisener badge handler class
 */
interface IListenerBadges is IPausable {

    event ListenerBadgeUpdated(address indexed listener, uint256 badge);

    /**
     * @dev Update the listener custom coefficient
     */
    function updateListenerBadge(address listener, uint64 badge) external;

    /**
     * @dev Find the badge for the given listener
     */
    function getListenerBadge(address listener) external view returns (uint64);
}
