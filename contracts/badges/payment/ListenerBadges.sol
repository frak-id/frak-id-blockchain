// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IListenerBadges.sol";
import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
contract ListenerBadges is IListenerBadges, SybelAccessControlUpgradeable {
    // Map of user address to listener badge
    mapping(address => uint64) private listenerBadges;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grant the badge updater role to the contract deployer
        _grantRole(SybelRoles.BADGE_UPDATER, _msgSender());
    }

    /**
     * @dev Update the listener snft amount
     */
    function updateBadge(address listener, uint64 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        listenerBadges[listener] = badge;
    }

    /**
     * @dev Find the badge for the given listener (on a 1e18 scale)
     */
    function getBadge(address listener) external view override returns (uint64 listenerBadge) {
        listenerBadge = listenerBadges[listener];
        if (listenerBadge == 0) {
            // If the badge of this listener isn't set yet, set it to default
            listenerBadge = 1 ether;
        }
        return listenerBadge;
    }
}
