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

    struct PositionInfo {
        address user;
        uint256 share;
        uint256 enterBlockNumber;
        uint256 lastClaimBlockNumber;
    }

    struct CompiledReward {
        uint256 count;
        uint256 rewardBalance;
        uint256 currentBlockNumber;
        uint256 lastBlockNumber;
    }

    CompiledReward[] private rewards;

    mapping(address => PositionInfo) private positions;

    function rewardAdded() {
        // Get the current balance
        uint256 currentBalance = sybelToken.balanceOf(address(this));
        // TODO : Compute the balance differences
        uint256 balanceDiff = currentBalance;
        if (rewards.count > 0) {
            // Get the last rewards stored
            CompiledReward storage lastReward = rewards[rewards.count];
            lastReward.count += 1;
            lastReward.rewardBalance += balanceDiff;
            lastReward.lastBlockNumber = block.number;
            // TODO : How to handle the fact that we need a new reward object because of pass tx ???
        } else {
            // Create a new reward if needed
            CompiledReward newReward = CompiledReward(
                1,
                balanceDiff,
                block.number,
                block.number
            );
            rewards.push(newReward);
        }
    }

    function updateUserShare(address user, uint256 share) {
        require(address != address(0));
        PositionInfo storage info = positions.get(user);
        // Check if the share is really updated
        require(info.share != share);
        // Check if the user have some reward to be claimed
    }

    function claimUserReward(address user) {
        PositionInfo storage info = positions.get(user);
        require(info.share > 0);

        // Check the last time the user claimed his reward, and get the compiled reward associated
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
