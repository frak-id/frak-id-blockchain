// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IRewarder.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelToken.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @dev Represent our content pool contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract ContentPool {
    /**
     * @dev Event emitted when the pool receive some money
     */
    event PoolProvisionned(uint256 podcastId, uint256 amount);
    /**
     * @dev Event emitted when a user is withdraw his found in the pool
     */
    event PoolWithdraw(uint256 podcastId, address user, uint256 amount);
    /**
     * @dev Event emitted when a user is added to a pool
     */
    event PoolParticipantAdded(uint256 podcastId, address user);
    /**
     * @dev Event emitted when a user is removed from a pool
     */
    event PoolParticipantRemoved(uint256 podcastId, address user);
    /**
     * @dev Event emitted when a user share is updated in a pool
     */
    event PoolParticipantShareUpdated(
        uint256 podcastId,
        address user,
        uint256 share
    );
    /**
     * @dev Event
     */
    event ReferralRewardWithdrawed(address user, uint256 amount);

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    // Add enumarable map library methods
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // User addresses to their shares
    EnumerableMap.AddressToUintMap private addressesToShare;

    // User pending rewards
    mapping(address => uint256) private userPendingReward;

    /**
     * @dev The content id for which we create this pool
     */
    uint256 private contentId;

    /**
     * @dev The total shares of this pool
     */
    uint256 private totalShares;

    constructor(address sybelTokenAddr, uint256 id) {
        contentId = id;

        // Init our sybel token
        sybelToken = SybelToken(sybelTokenAddr);
    }

    function addUserShare(address user, uint256 shareToAdd) external {
        require(
            user != address(0),
            "SYB: Can't update shares of the 0 address"
        );
        require(shareToAdd > 0, "SYB: Can't add 0 share to the user");
        // Try to get the user
        (bool success, uint256 previousShare) = addressesToShare.tryGet(user);
        if (success) {
            // If user already in the set
            uint256 newShare = previousShare + shareToAdd;
            addressesToShare.set(user, newShare);
        } else {
            // If user not in the set
            addressesToShare.set(user, shareToAdd);
        }
        // Then, in all the case, increase the total shares
        totalShares += shareToAdd;
    }

    function removeUserShare(address user, uint256 shareToRemove) external {
        require(
            user != address(0),
            "SYB: Can't update shares of the 0 address"
        );
        require(shareToRemove > 0, "SYB: Can't remove 0 share to the user");
        // Try to get the user
        (bool success, uint256 previousShare) = addressesToShare.tryGet(user);
        if (success && (previousShare - shareToRemove > 0)) {
            // If user already in the set and his balance won't go to 0
            uint256 newShare = previousShare - shareToRemove;
            addressesToShare.set(user, newShare);
            // Then decrease the total shares by the diff
            totalShares -= shareToRemove;
        } else if (success && (previousShare - shareToRemove <= 0)) {
            // In the case he is in the set but his balance go down to 0 or less
            addressesToShare.remove(user);
            // Then decrease the total shares by the share the user got on this pool
            totalShares -= previousShare;
        }
        // Otherwise, if his not in the set, do nothing
    }

    /**
     * When this contract got some reward
     */
    function computeRewardForUser(uint256 rewardAmount) external {
        require(rewardAmount > 0, "SYB: Can't add 0 as reward");
        // Compute the reward for each one of our user
        for (uint256 index = 0; index < addressesToShare.length(); index++) {
            // Get the address at the current index
            (address user, uint256 userShares) = addressesToShare.at(index);
            // Compute the user reward
            uint256 userReward = (rewardAmount * userShares) / totalShares;
            // Store it
            userPendingReward[user] += userReward;
        }
    }

    /**
     * Withdraw the user pending founds
     */
    function withdrawFounds(address user) external {
        require(
            user != address(0),
            "SYB: Can't withdraw content pool founds for the 0 address"
        );
        // Ensure the user have a pending reward
        uint256 pendingReward = userPendingReward[user];
        require(pendingReward > 0, "SYB: The user havn't any pending reward");
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = sybelToken.balanceOf(address(this));
        require(
            contractBalance > pendingReward,
            "SYB: The referral contract hasn't the required founds to pay the user"
        );
        // Reset the user pending balance
        userPendingReward[user] = 0;
        // Perform the transfer of the founds
        sybelToken.transfer(user, pendingReward);
    }
}
