// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakMath } from "../../lib/FrakMath.sol";
import { FraktionId } from "../../lib/FraktionId.sol";
import { ContentIdLib } from "../../lib/ContentId.sol";
import { InvalidFraktionType } from "../../utils/FrakErrors.sol";

/// @author @KONFeature
/// @title FractionCostBadges
/// @notice Abstract contract for managing the badge costs of fractions.
/// @custom:security-contact contact@frak.id
abstract contract FractionCostBadges {
    /* -------------------------------------------------------------------------- */
    /*                                   Error's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256("InvalidFraktionType()"))'
    uint256 private constant _INVALID_FRAKTION_TYPE_SELECTOR = 0x3f126a45;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Emitted when the badge cost of a fraction is updated.
     * @param id The id of the updated fraction.
     * @param badge The new badge cost of the fraction in wei.
     */
    event FractionCostBadgeUpdated(uint256 indexed id, uint256 badge);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Map f nft id to cost badge.
     * @notice This variable is private and can only be accessed by the current contract.
     */
    mapping(FraktionId frakionId => uint96 cost) private fractionBadges;

    /* -------------------------------------------------------------------------- */
    /*                             Abstract function's                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraction.
     * @notice This function can be overridden by inheriting contracts.
     * @param fractionId The id of the fraction to update the badge cost of.
     * @param badge The new badge cost of the fraction in wei.
     */
    function updateCostBadge(FraktionId fractionId, uint96 badge) external virtual;

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraction and emit an event.
     * @param fractionId The id of the fraction to update the badge cost of.
     * @param badge The new badge cost of the fraction in wei.
     */
    function _updateCostBadge(FraktionId fractionId, uint96 badge) internal {
        fractionBadges[fractionId] = badge;
        emit FractionCostBadgeUpdated(FraktionId.unwrap(fractionId), badge);
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
    function getCostBadge(FraktionId fractionId) public view returns (uint96 fractionBadge) {
        fractionBadge = fractionBadges[fractionId];
        if (fractionBadge == 0) {
            // If the badge of this fraction isn't set yet, set it to default
            uint256 tokenType = fractionId.getFraktionType();
            fractionBadge = initialFractionCost(tokenType);
        }
    }

    /**
     * @dev Returns the initial cost of a fraction of the specified token type in wei.
     * @notice This method should only be called with valid token types as defined by the FrakMath contract.
     * @param tokenType The type of token to get the initial cost of.
     * @return initialCost The initial cost of the specified token type in wei.
     */
    function initialFractionCost(uint256 tokenType) internal pure returns (uint96 initialCost) {
        if (tokenType == ContentIdLib.FRAKTION_TYPE_COMMON) {
            initialCost = 90 ether; // 90 FRK
        } else if (tokenType == ContentIdLib.FRAKTION_TYPE_PREMIUM) {
            initialCost = 500 ether; // 500 FRK
        } else if (tokenType == ContentIdLib.FRAKTION_TYPE_GOLD) {
            initialCost = 1200 ether; // 1.2k FRK
        } else if (tokenType == ContentIdLib.FRAKTION_TYPE_DIAMOND) {
            initialCost = 3000 ether; // 3k FRK
        } else {
            assembly {
                mstore(0x00, _INVALID_FRAKTION_TYPE_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }
}
