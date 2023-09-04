// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

/// @dev Define the FraktionId type
type FraktionId is uint256;

/// @dev Tell to use the lib below for every FraktionId instance
using FraktionIdLib for FraktionId global;

/// @author @KONFeature
/// @title FraktionIdLib
/// @notice This contract is used to help us with the manipulation of the FraktionId
/// @custom:security-contact contact@frak.id
library FraktionIdLib {
    /// @dev The offset of the id we use to store the fraktion type
    uint256 internal constant ID_OFFSET = 4;
    /// @dev The mask we use to store the fraktion type in the fraktion id
    uint256 internal constant TYPE_MASK = 0xF;

    /// @dev Get the `contentId` from the `self` fraktion id
    function getContentId(FraktionId self) internal pure returns (uint256 contentId) {
        assembly {
            contentId := shr(ID_OFFSET, self)
        }
    }

    /// @dev Get the `fraktionType` from the `self` fraktion id
    function getFraktionType(FraktionId self) internal pure returns (uint256 fraktionType) {
        assembly {
            fraktionType := and(self, TYPE_MASK)
        }
    }

    /// @dev Get the `contentId` and `fraktionType` from the `self` fraktion id
    function extractAll(FraktionId self) internal pure returns (uint256 contentId, uint256 fraktionType) {
        assembly {
            contentId := shr(ID_OFFSET, self)
            fraktionType := and(self, TYPE_MASK)
        }
    }

    /// @dev Create a new array with the given element
    function asSingletonArray(FraktionId self) internal pure returns (FraktionId[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), self)
        }
    }
}
