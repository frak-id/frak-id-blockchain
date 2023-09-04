// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

/// @dev Struct representing the accounter for the reward
struct RewardAccounter {
    uint256 user;
    uint256 owners;
    uint256 content;
}

/// @dev Tell to use the lib below for every RewardAccounter instance
using RewardAccounterLib for RewardAccounter global;

/// @dev 1 ether in WAD
uint256 constant WAD = 1 ether;

/// @author @KONFeature
/// @title RewardAccounterLib
/// @notice Library to ease the usage of the RewardAccounter struct
/// @custom:security-contact contact@frak.id
library RewardAccounterLib {
    /// @dev Apply the user `badge` booster on the user reward
    function applyUserBadge(RewardAccounter memory self, uint256 badge) internal pure {
        unchecked {
            self.user = self.user * badge / WAD;
        }
    }

    /// @dev Get the total amount in the accounter
    function getTotal(RewardAccounter memory self) internal pure returns (uint256 total) {
        unchecked {
            total = self.user + self.owners + self.content;
        }
    }
}
