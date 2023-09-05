// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionId } from "./FraktionId.sol";

/// @author @KONFeature
/// @title ArrayLib
/// @notice Lib to help us manage array
/// @custom:security-contact contact@frak.id
library ArrayLib {
    /// @dev Wrap a uint256 to a FraktionId type
    function asFraktionIds(uint256[] memory self) internal pure returns (FraktionId[] memory fraktionIds) {
        assembly {
            fraktionIds := self
        }
    }

    /// @dev Create a singleton array of the given element
    function asSingletonArray(uint256 element) internal pure returns (uint256[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), element)
        }
    }

    /// @dev Create a singleton array of the given element
    function asSingletonArray(address element) internal pure returns (address[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), element)
        }
    }
}
