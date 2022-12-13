// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../../utils/FrakMath.sol";
import "../../utils/FrakRoles.sol";
import "../../utils/FrakAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our content badges
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract ContentBadges {
    uint256 private constant MAX_CONTENT_BADGE = 1_000 ether; // Max badge possible for the content

    // Map content id to content badge
    mapping(uint256 => uint256) private _contentBadges;

    event ContentBadgeUpdated(uint256 indexed id, uint256 badge);

    function updateContentBadge(uint256 contentId, uint256 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateContentBadge(uint256 contentId, uint256 badge) internal {
        if (badge > MAX_CONTENT_BADGE) revert BadgeTooLarge();
        _contentBadges[contentId] = badge;
        emit ContentBadgeUpdated(contentId, badge);
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function getContentBadge(uint256 contentId) public view returns (uint256 badge) {
        badge = _contentBadges[contentId];
        if (badge == 0) {
            // If the badge of this content isn't set yet, set it to default
            badge = 1 ether;
        }
        return badge;
    }
}
