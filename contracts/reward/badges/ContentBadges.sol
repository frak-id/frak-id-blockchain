// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { ContentId } from "../../libs/ContentId.sol";
import { BadgeTooLarge } from "../../utils/FrakErrors.sol";

/// @author @KONFeature
/// @title ContentBadges
/// @notice Abstract contract for managing the content badge use as multiplier for earnings.
/// @custom:security-contact contact@frak.id
abstract contract ContentBadges {
    /// @dev Max badge possible for the content
    uint256 private constant MAX_CONTENT_BADGE = 1000 ether;

    /// @dev Event emitted when a badge is updated
    event ContentBadgeUpdated(uint256 indexed id, uint256 badge);

    /// @dev Mapping of content id to content badge
    mapping(ContentId contentId => uint256 badge) private _contentBadges;

    /// @dev external function used to update the content badges
    function updateContentBadge(ContentId contentId, uint256 badge) external virtual;

    /// @dev Update the content 'id' badge to 'badge'
    function _updateContentBadge(ContentId contentId, uint256 badge) internal {
        if (badge > MAX_CONTENT_BADGE) revert BadgeTooLarge();
        _contentBadges[contentId] = badge;
        emit ContentBadgeUpdated(ContentId.unwrap(contentId), badge);
    }

    /// @dev Get the content badges for the content 'id'
    function getContentBadge(ContentId contentId) public view returns (uint256 badge) {
        assembly {
            // Get the current content badge
            // Kecak (contentId, _contentBadges.slot)
            mstore(0, contentId)
            mstore(0x20, _contentBadges.slot)
            // Load it
            badge := sload(keccak256(0, 0x40))
            // If null, set it to 1 ether by default
            if iszero(badge) { badge := 1000000000000000000 }
        }
    }
}
