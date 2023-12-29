// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { FraktionId } from "./FraktionId.sol";

/// @dev Define the ContentId type
type ContentId is uint256;

/// @dev Tell to use the lib below for every ContentId instance
using ContentIdLib for ContentId global;

/// @author @KONFeature
/// @title ContentIdLib
/// @notice This contract is used to help us with the manipulation of the ContentId
/// @custom:security-contact contact@frak.id
library ContentIdLib {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The offset of the id we use to store the fraktion type
    uint256 internal constant ID_OFFSET = 4;
    /// @dev The mask we use to store the fraktion type in the fraktion id
    uint256 internal constant TYPE_MASK = 0xF;

    /// @dev NFT Token type mask
    uint256 internal constant FRAKTION_TYPE_CREATOR = 1;
    /// @dev Free Token type mask
    uint256 internal constant FRAKTION_TYPE_FREE = 2;
    /// @dev Common Token type mask
    uint256 internal constant FRAKTION_TYPE_COMMON = 3;
    /// @dev Premium Token type mask
    uint256 internal constant FRAKTION_TYPE_PREMIUM = 4;
    /// @dev Gold Token type mask
    uint256 internal constant FRAKTION_TYPE_GOLD = 5;
    /// @dev Diamond Token type mask
    uint256 internal constant FRAKTION_TYPE_DIAMOND = 6;

    /* -------------------------------------------------------------------------- */
    /*                               Helper functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Build a fraktion id from a content id
    function toFraktionId(ContentId self, uint256 fraktionType) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), fraktionType)
        }
    }

    /// @dev Build the id for a creator NFT id
    function creatorFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_CREATOR)
        }
    }

    /// @dev Build the id for a free NFT id
    function freeFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_FREE)
        }
    }

    /// @dev Build the id for a common NFT id
    function commonFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_COMMON)
        }
    }

    /// @dev Build the id for a premium NFT id
    function premiumFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_PREMIUM)
        }
    }

    /// @dev Build the id for a gold NFT id
    function goldFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_GOLD)
        }
    }

    /// @dev Build the id for a diamond NFT id
    function diamondFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_DIAMOND)
        }
    }

    /// @dev Build an array of all the payable fraktion types
    function payableFraktionIds(ContentId self) internal pure returns (FraktionId[] memory ids) {
        assembly {
            // Store each types
            ids := mload(0x40)
            mstore(ids, 4)
            mstore(add(ids, 0x20), or(shl(ID_OFFSET, self), FRAKTION_TYPE_COMMON))
            mstore(add(ids, 0x40), or(shl(ID_OFFSET, self), FRAKTION_TYPE_PREMIUM))
            mstore(add(ids, 0x60), or(shl(ID_OFFSET, self), FRAKTION_TYPE_GOLD))
            mstore(add(ids, 0x80), or(shl(ID_OFFSET, self), FRAKTION_TYPE_DIAMOND))
            // Update our free mem space
            mstore(0x40, add(ids, 0xA0))
        }
    }

    /// @dev Create a new array with the given element
    function asSingletonArray(ContentId self) internal pure returns (ContentId[] memory array) {
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
