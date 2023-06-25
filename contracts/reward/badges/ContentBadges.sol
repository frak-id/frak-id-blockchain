// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {BadgeTooLarge} from "../../utils/FrakErrors.sol";

/**
 * @author  @KONFeature
 * @title   ContentBadges
 * @dev Abstract contract for managing the content badge use as multiplier for earnings.
 * @notice This contract contains methods and variables for initializing, updating, and getting the content badges.
 * @custom:security-contact contact@frak.id
 */
abstract contract ContentBadges {
    /// @dev Max badge possible for the content
    uint256 private constant MAX_CONTENT_BADGE = 1_000 ether;

    /// @dev Event emitted when a badge is updated
    event ContentBadgeUpdated(uint256 indexed id, uint256 badge);

    /// @dev Mapping of content id to content badge
    mapping(uint256 => uint256) private _contentBadges;

    /// @dev external function used to update the content badges
    function updateContentBadge(uint256 contentId, uint256 badge) external virtual;

    /// @dev Update the content 'id' badge to 'badge'
    function _updateContentBadge(uint256 contentId, uint256 badge) internal {
        if (badge > MAX_CONTENT_BADGE) revert BadgeTooLarge();
        _contentBadges[contentId] = badge;
        emit ContentBadgeUpdated(contentId, badge);
    }

    /// @dev Get the content badges for the content 'id'
    function getContentBadge(uint256 contentId) public view returns (uint256 badge) {
        assembly {
            // Get the current content badge
            // Kecak (contentId, _contentBadges.slot)
            mstore(0, contentId)
            mstore(0x20, _contentBadges.slot)
            let badgeSlot := keccak256(0, 0x40)
            // Load it
            badge := sload(badgeSlot)
            // If null, set it to 1 ether by default
            if iszero(badge) { badge := 1000000000000000000 }
        }
    }
}
