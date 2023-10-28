// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionId } from "../../libs/FraktionId.sol";
import { ContentIdLib } from "../../libs/ContentId.sol";
import { InvalidFraktionType } from "../../utils/FrakErrors.sol";

/// @author @KONFeature
/// @title FraktionCostBadges
/// @notice Abstract contract for managing the badge costs of fraktions.
/// @custom:security-contact contact@frak.id
abstract contract FraktionCostBadges {
    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256("InvalidFraktionType()"))'
    uint256 private constant _INVALID_FRAKTION_TYPE_SELECTOR = 0x3f126a45;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Emitted when the badge cost of a fraktion is updated.
     * @param id The id of the updated fraktion.
     * @param badge The new badge cost of the fraktion in wei.
     */
    event FraktionCostBadgeUpdated(uint256 indexed id, uint256 badge);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Map f nft id to cost badge.
     * @notice This variable is private and can only be accessed by the current contract.
     */
    mapping(FraktionId frakionId => uint96 cost) private fraktionBadges;

    /* -------------------------------------------------------------------------- */
    /*                             Abstract functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraktion.
     * @notice This function can be overridden by inheriting contracts.
     * @param fraktionId The id of the fraktion to update the badge cost of.
     * @param badge The new badge cost of the fraktion in wei.
     */
    function updateCostBadge(FraktionId fraktionId, uint96 badge) external virtual;

    /* -------------------------------------------------------------------------- */
    /*                          Internal write functions                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the badge cost of the specified fraktionId and emit an event.
     * @param fraktionId The id of the fraktionId to update the badge cost of.
     * @param badge The new badge cost of the fraktionId in wei.
     */
    function _updateCostBadge(FraktionId fraktionId, uint96 badge) internal {
        // Revert if the fraktion id is not a payable one
        if (fraktionId.isNotPayable()) {
            revert InvalidFraktionType();
        }

        fraktionBadges[fraktionId] = badge;
        emit FraktionCostBadgeUpdated(FraktionId.unwrap(fraktionId), badge);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Public read functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Returns the badge cost of the specified fraktion.
     * @notice If the badge of this fraktionId isn't set yet, it will be set to the default initial cost.
     * @param fraktionId The id of the fraktionId to get the badge cost of.
     * @return fraktionBadge The badge cost of the specified fraktionId in wei.
     */
    function getCostBadge(FraktionId fraktionId) public view returns (uint96 fraktionBadge) {
        fraktionBadge = fraktionBadges[fraktionId];
        if (fraktionBadge == 0) {
            // If the badge of this fraktionId isn't set yet, set it to default
            uint256 fraktionType = fraktionId.getFraktionType();
            fraktionBadge = initialFraktionCost(fraktionType);
        }
    }

    /**
     * @dev Returns the initial cost of a fraktionId of the specified fraktion type in wei.
     * @notice This method should only be called with valid fraktion types as defined by the FrakMath contract.
     * @param fraktionType The type of fraktion to get the initial cost of.
     * @return initialCost The initial cost of the specified fraktion type in wei.
     */
    function initialFraktionCost(uint256 fraktionType) internal pure returns (uint96 initialCost) {
        if (fraktionType == ContentIdLib.FRAKTION_TYPE_COMMON) {
            initialCost = 90 ether; // 90 FRK
        } else if (fraktionType == ContentIdLib.FRAKTION_TYPE_PREMIUM) {
            initialCost = 500 ether; // 500 FRK
        } else if (fraktionType == ContentIdLib.FRAKTION_TYPE_GOLD) {
            initialCost = 1200 ether; // 1.2k FRK
        } else if (fraktionType == ContentIdLib.FRAKTION_TYPE_DIAMOND) {
            initialCost = 3000 ether; // 3k FRK
        } else {
            assembly {
                mstore(0x00, _INVALID_FRAKTION_TYPE_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }
}
