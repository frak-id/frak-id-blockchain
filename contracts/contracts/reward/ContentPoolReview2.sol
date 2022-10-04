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
 * @dev TODO : Optimize uint sizes (since max supply of sybl is 3 billion e18, what's the max uint we can use for the price ?, What the max array size ? So what max uint for indexes ?)
 */
/// @custom:security-contact crypto-support@sybel.co
contract ContentPool {
    struct RewardState {
        uint256 totalShares;
        uint256 currentPoolReward;
        uint256 totalClaimedReward; // Used to check when the pool if fully cleaned up or not
        bool open;
    }

    struct Participant {
        uint256 shares;
        uint256 enterStateIndex;
        uint256 lastStateIndex;
        uint256[] sharesByState;
        // Last withdraw timestamp ?
    }

    RewardState[] private rewardStates;

    EnumerableMap.Bytes32ToBytes32Map[] private testMapArray;

    mapping(address => Participant) participants;

    mapping(uint256 => mapping(address => uint256)) claimedRewards;

    uint256 private currentStateIndex;

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * TODO : Should be able to handle reward amount directly from sybel token ??
     */
    function addReward(uint256 rewardAmount) external {
        // TODO : Add some check and security
        RewardState storage currentState = rewardStates[currentStateIndex];
        currentState.currentPoolReward += rewardAmount;
    }

    function updateParticipant(address user, uint256 shares) external {
        // If share == 0, delete
        // Perform lock on state index
        // Close the last RewardState (is it enough as lock ??)
        RewardState storage currentState = rewardStates[currentStateIndex];
        currentState.open = false;
        // Update the participant
        Participant storage currentParticipant = participants[user];
        int256 shareDifference = int256(
            shares - currentParticipant.sharesByState[currentStateIndex]
        );
        currentParticipant.shares = shares;
        // Increase the current reward index and create the new one
        currentStateIndex++;
        rewardStates[currentStateIndex] = RewardState(
            uint256(currentState.totalShares += uint256(shareDifference)), // total shares
            0, // current reward
            0, // total claimed reward
            true // open state
        );
        // Update the user shares by pool
        currentParticipant.sharesByState[currentStateIndex] = shares;
    }

    function claimReward(address user) external {
        // Get the participant
        Participant storage participant = participants[user];
        // TODO : Some require
        // TODO : Check if
        uint256 toBePayed = 0;
        // TODO : Have a state count cap to be able to handle edge case like long time not checked ones (cap to 200 hundred max ??)
        for (
            uint256 stateIndex = participant.lastStateIndex;
            stateIndex < currentStateIndex;
            stateIndex++
        ) {
            // Get the reward the user claimed on this state
            uint256 alreadyClaimedRewards = claimedRewards[stateIndex][user];
            uint256 stateShare = participant.sharesByState[stateIndex];
            // Get the state
            RewardState storage state = rewardStates[stateIndex];
            // Compute the total reward tor this user in this state
            uint256 totalPoolReward = (state.currentPoolReward * stateShare) /
                state.totalShares;
            toBePayed += totalPoolReward - alreadyClaimedRewards;
        }
        // Update the last handled index for the user
        participant.lastStateIndex = currentStateIndex;
        // Safe this amount for the user ?
        // Transfer from this contract to the user directly ??
        // Ensure the balance is enough
    }
}
