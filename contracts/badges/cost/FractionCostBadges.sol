// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IFractionCostBadges.sol";
import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact crypto-support@sybel.co
contract FractionCostBadges is IFractionCostBadges, SybelAccessControlUpgradeable {
    // Map f nft id to cost badge
    mapping(uint256 => uint256) private fractionBadges;

    event FractionCostBadgeUpdated(uint256 id, uint256 badge);

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
     * @dev Update the content internal coefficient
     */
    function updateBadge(uint256 fractionId, uint256 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        fractionBadges[fractionId] = badge;
        emit FractionCostBadgeUpdated(fractionId, badge);
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function getBadge(uint256 fractionId) external view override whenNotPaused returns (uint256 fractionBadge) {
        fractionBadge = fractionBadges[fractionId];
        if (fractionBadge == 0) {
            // If the badge of this fraction isn't set yet, set it to default
            uint8 tokenType = SybelMath.extractTokenType(fractionId);
            fractionBadge = initialFractionCost(tokenType);
        }
        return fractionBadge;
    }

    /**
     * @dev The initial cost of a fraction type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function initialFractionCost(uint8 tokenType) public pure returns (uint256 initialCost) {
        if (tokenType == SybelMath.TOKEN_TYPE_CLASSIC_MASK) {
            initialCost = 20 ether; // 20 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_RARE_MASK) {
            initialCost = 100 ether; // 100 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_EPIC_MASK) {
            initialCost = 200 ether; // 200 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_LEGENDARY_MASK) {
            initialCost = 400 ether; // 400 SYBL
        }
        return initialCost;
    }
}
