// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/IPausable.sol";

/**
 * @dev Represent our lisener badge handler class
 */
interface IListenerBadges is IPausable {
    /**
     * @dev Update the listener custom coefficient
     */
    function updateBadge(address _listener, uint64 _badge) external;

    /**
     * @dev Find the badge for the given listener
     */
    function getBadge(address _listener) external view returns (uint64);
}
