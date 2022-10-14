// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../utils/IPausable.sol";

/**
 * @dev Represent our content badge contract
 */
interface IContentBadges is IPausable {
    /**
     * @dev Update the listener custom coefficient
     */
    function updateBadge(uint256 contentId, uint256 _badge) external;

    /**
     * @dev Get the payment badges for the given informations
     */
    function getBadge(uint256 contentId) external returns (uint256);
}
