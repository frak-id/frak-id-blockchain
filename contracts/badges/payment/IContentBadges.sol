// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/IPausable.sol";

/**
 * @dev Represent our content badge contract
 */
interface IContentBadges is IPausable {

    event ContentBadgeUpdated(uint256 indexed id, uint256 badge);

    /**
     * @dev Update the listener custom coefficient
     */
    function updateContentBadge(uint256 contentId, uint256 badge) external;

    /**
     * @dev Get the payment badges for the given informations
     */
    function getContentBadge(uint256 contentId) external returns (uint256);
}
