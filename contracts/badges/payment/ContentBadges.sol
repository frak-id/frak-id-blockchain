// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IContentBadges.sol";
import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract ContentBadges is IContentBadges {
    // Map content id to content badge
    mapping(uint256 => uint256) private _contentBadges;

    function updateContentBadge(uint256 contentId, uint256 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateContentBadge(uint256 contentId, uint256 badge)
        internal
    {
        _contentBadges[contentId] = badge;
        emit ContentBadgeUpdated(contentId, badge);
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function _getContentBadge(uint256 contentId) internal view returns (uint256 badge) {
        badge = _contentBadges[contentId];
        if (badge == 0) {
            // If the badge of this content isn't set yet, set it to default
            badge = 1 ether;
        }
        return badge;
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function getContentBadge(uint256 contentId) external view override returns (uint256) {
        return _getContentBadge(contentId);
    }
}
