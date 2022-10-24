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
contract ContentBadges is IContentBadges, SybelAccessControlUpgradeable {
    // Map content id to content badge
    mapping(uint256 => uint256) private contentBadges;

    event ContentBadgeUpdated(uint256 indexed id, uint256 badge);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grant the badge updater role to the contract deployer
        _grantRole(SybelRoles.BADGE_UPDATER, msg.sender);
    }

    /**
     * @dev Update the content internal coefficient
     */
    function updateBadge(uint256 contentId, uint256 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        contentBadges[contentId] = badge;
        emit ContentBadgeUpdated(contentId, badge);
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function getBadge(uint256 contentId) external view override whenNotPaused returns (uint256 badge) {
        badge = contentBadges[contentId];
        if (badge == 0) {
            // If the badge of this content isn't set yet, set it to default
            badge = 1 ether;
        }
        return badge;
    }
}
