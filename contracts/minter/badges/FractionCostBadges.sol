// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../../utils/FrakMath.sol";
import "../../utils/FrakRoles.sol";
import "../../utils/FrakAccessControlUpgradeable.sol";

/**
 * @dev Handle the computation of our listener badges
 */
/// @custom:security-contact contact@frak.id
abstract contract FractionCostBadges {
    event FractionCostBadgeUpdated(uint256 id, uint96 badge);

    // Map f nft id to cost badge
    mapping(uint256 => uint96) private fractionBadges;

    function updateCostBadge(uint256 fractionId, uint96 badge) external virtual;

    /**
     * @dev Update the content internal coefficient
     */
    function _updateCostBadge(uint256 fractionId, uint96 badge) internal {
        fractionBadges[fractionId] = badge;
        emit FractionCostBadgeUpdated(fractionId, badge);
    }

    /**
     * @dev Get the payment badges for the given informations
     */
    function getCostBadge(uint256 fractionId) public view returns (uint96 fractionBadge) {
        fractionBadge = fractionBadges[fractionId];
        if (fractionBadge == 0) {
            // If the badge of this fraction isn't set yet, set it to default
            uint8 tokenType = FrakMath.extractTokenType(fractionId);
            fractionBadge = initialFractionCost(tokenType);
        }
        return fractionBadge;
    }

    /**
     * @dev The initial cost of a fraction type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function initialFractionCost(uint8 tokenType) public pure returns (uint96 initialCost) {
        if (tokenType == FrakMath.TOKEN_TYPE_COMMON_MASK) {
            initialCost = 20 ether; // 20 FRK
        } else if (tokenType == FrakMath.TOKEN_TYPE_PREMIUM_MASK) {
            initialCost = 100 ether; // 100 FRK
        } else if (tokenType == FrakMath.TOKEN_TYPE_GOLD_MASK) {
            initialCost = 200 ether; // 200 FRK
        } else if (tokenType == FrakMath.TOKEN_TYPE_DIAMOND_MASK) {
            initialCost = 400 ether; // 400 FRK
        } else {
            revert InvalidFraktionType();
        }
        return initialCost;
    }
}
