// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {InvalidFraktionType} from "../../utils/FrakErrors.sol";

/**
 * @author  @KONFeature
 * @title   FractionCostBadges
 * @dev Abstract contract for managing the badge costs of fractions.
 * @notice This contract contains methods and variables for initializing, updating, and getting the badge costs of fractions.
 * @custom:security-contact contact@frak.id
 */
abstract contract FractionCostBadges {
    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Emitted when the badge cost of a fraction is updated.
     * @param id The id of the updated fraction.
     * @param badge The new badge cost of the fraction in wei.
     */
    event FractionCostBadgeUpdated(uint256 id, uint96 badge);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Map f nft id to cost badge.
     * @notice This variable is private and can only be accessed by the current contract.
     */
    mapping(uint256 => uint96) private fractionBadges;

    /* -------------------------------------------------------------------------- */
    /*                             Abstract function's                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraction.
     * @notice This function can be overridden by inheriting contracts.
     * @param fractionId The id of the fraction to update the badge cost of.
     * @param badge The new badge cost of the fraction in wei.
     */
    function updateCostBadge(uint256 fractionId, uint96 badge) external virtual;

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraction and emit an event.
     * @param fractionId The id of the fraction to update the badge cost of.
     * @param badge The new badge cost of the fraction in wei.
     */
    function _updateCostBadge(uint256 fractionId, uint96 badge) internal {
        fractionBadges[fractionId] = badge;
        emit FractionCostBadgeUpdated(fractionId, badge);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Public read function's                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Returns the badge cost of the specified fraction.
     * @notice If the badge of this fraction isn't set yet, it will be set to the default initial cost.
     * @param fractionId The id of the fraction to get the badge cost of.
     * @return fractionBadge The badge cost of the specified fraction in wei.
     */
    function getCostBadge(uint256 fractionId) public view returns (uint96 fractionBadge) {
        fractionBadge = fractionBadges[fractionId];
        if (fractionBadge == 0) {
            // If the badge of this fraction isn't set yet, set it to default
            uint256 tokenType = FrakMath.extractTokenType(fractionId);
            fractionBadge = initialFractionCost(tokenType);
        }
        return fractionBadge;
    }

    /**
     * @dev Returns the initial cost of a fraction of the specified token type in wei.
     * @notice This method should only be called with valid token types as defined by the FrakMath contract.
     * @param tokenType The type of token to get the initial cost of.
     * @return initialCost The initial cost of the specified token type in wei.
     */
    function initialFractionCost(uint256 tokenType) internal pure returns (uint96 initialCost) {
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
