// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { ContentId } from "../libs/ContentId.sol";

/// @dev Define the reward Listen param type
/// @dev Its contains the number of listen performd by a user `listenCount` and the content id `contentId`
/// @dev It's build as folow [contentId -> bytes29][listenCount -> bytes3] -> bytes32
type RewardListenParam is bytes32;

/// @dev Tell to use the lib below for every ContentId instance
using RewardListenParamLib for RewardListenParam global;

/// @author @KONFeature
/// @title RewardListenParamLib
/// @notice This contract is used to help us with the manipulation of the RewardListenParam type
/// @custom:security-contact contact@frak.id
library RewardListenParamLib {
    /// @dev The mask we used to retreive the listen count
    uint256 internal constant LISTEN_COUNT_MASK = 0xFFF;

    /// @dev The offset used to store the content id (12 bits so just after the listen count)
    uint256 internal constant CONTENT_ID_OFFSET = 12;

    /* -------------------------------------------------------------------------- */
    /*                             Creation functions                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Build a fraktion id from a content id
    function build(ContentId contentId, uint16 listenCount) internal pure returns (RewardListenParam param) {
        assembly {
            // Put the content id in the first 30 bytes
            param := shl(CONTENT_ID_OFFSET, contentId)
            // Put the listen count in the last 2 bytes
            param := or(param, and(listenCount, LISTEN_COUNT_MASK))
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Setter functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Set the `listenCount` in the `self` RewardListenParam
    function setListenCount(
        RewardListenParam self,
        uint16 listenCount
    )
        internal
        pure
        returns (RewardListenParam newParam)
    {
        assembly {
            // Put the listen count in the last 2 bytes
            newParam := or(self, and(listenCount, LISTEN_COUNT_MASK))
        }
    }

    /// @dev Set the `contentId` in the `self` RewardListenParam
    function setContentId(
        RewardListenParam self,
        ContentId contentId
    )
        internal
        pure
        returns (RewardListenParam newParam)
    {
        assembly {
            newParam := shl(CONTENT_ID_OFFSET, contentId)
            newParam := or(newParam, and(self, LISTEN_COUNT_MASK))
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Getter functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the `listenCount` from the `self` RewardListenParam
    function getListenCount(RewardListenParam self) internal pure returns (uint16 listenCount) {
        assembly {
            listenCount := and(self, LISTEN_COUNT_MASK)
        }
    }

    /// @dev Get the `contentId` from the `self` RewardListenParam
    function getContentId(RewardListenParam self) internal pure returns (ContentId contentId) {
        assembly {
            contentId := shr(CONTENT_ID_OFFSET, self)
        }
    }
}
