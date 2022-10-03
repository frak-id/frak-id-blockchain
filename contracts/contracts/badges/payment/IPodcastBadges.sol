// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/IPausable.sol";

/**
 * @dev Represent our podcast badge contract
 */
interface IPodcastBadges is IPausable {
    /**
     * @dev Update the listener custom coefficient
     */
    function updateBadge(uint256 _podcastId, uint256 _badge) external;

    /**
     * @dev Get the payment badges for the given informations
     */
    function getBadge(uint256 _podcastId) external returns (uint256);
}
