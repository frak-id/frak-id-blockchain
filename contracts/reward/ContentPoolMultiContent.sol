// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @dev Represent our content pool contract
 * @dev TODO : Optimize uint sizes (since max supply of sybl is 3 billion e18,
 * what's the max uint we can use for the price ?, What the max array size ? So what max uint for indexes ?)
 */
/// @custom:security-contact crypto-support@sybel.co
contract ContentPoolMultiContent {
    struct RewardState {
        // First storage slot, remain 31 bytes
        uint128 totalShares;
        uint96 currentPoolReward;
        bool open;
    }

    // TODO : Do we reduce shares or not ?
    // TODO : How to update the state, callback on the erc1155 ? Not too costy for each operation ?
    struct Participant {
        // First storage slot, remain 40 bytes
        uint120 shares; // Number of shares in the content pool
        uint96 lastStateClaim; // The last state amount claimed
        // Second storage slot
        uint256 enterStateIndex; // When does this entered the pool. Really usefull to store that ?
        // Third storage slot
        uint256 lastStateIndex; // What was the last state index he claimed in the pool ?
        // Last withdraw timestamp ? For lock on that ? Like a claim max every 6 hours
    }

    /**
     * @dev The cap to prevent excessive gaz fees when computing user reward
     */
    uint256 private constant MAX_CLAIMABLE_REWARD_STATE_ROUNDS = 500;

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * @dev All the different reward states per content id
     */
    mapping(uint256 => RewardState[]) private rewardStates;

    /**
     * @dev Mapping between content id, to address to participant
     */
    mapping(uint256 => mapping(address => Participant)) private participants;

    /**
     * @dev The index of the current state index per content
     */
    mapping(uint256 => uint256) private currentStateIndex;

    /**
     * The pending reward for the given address
     */
    mapping(address => uint256) private userPendingReward;

    /**
     * Add a reward inside a content pool
     */
    function addReward(uint256 contentId, uint96 rewardAmount) external {
        require(rewardAmount > 0, "SYB: invalid reward");
        RewardState storage currentState = lastContentState(contentId);
        require(currentState.open, "SYB: reward state closed");
        currentState.currentPoolReward += rewardAmount;
    }

    /**
     * @dev Update a participant share in a pool
     */
    function updateParticipant(
        uint256 contentId,
        address user,
        uint120 newShares
    ) external {
        require(user != address(0), "SYBL: invalid address");
        // Close the last RewardState and lock it
        (RewardState storage currentState, uint256 stateIndex) = lastContentStateWithIndex(contentId);
        currentState.open = false;
        // Get the participant and check the share differences
        Participant storage currentParticipant = participants[contentId][user];
        require(newShares != currentParticipant.shares, "SYB: invalid share");
        // Compute the new reward state shares
        // TODO : WARNIIIING, Ensure this don't update previous state (and so not a a memory ref to the var)
        uint128 newTotalShares;
        if (newShares > currentParticipant.shares) {
            newTotalShares = currentState.totalShares + newShares - currentParticipant.shares;
        } else {
            newTotalShares = currentState.totalShares - currentParticipant.shares - newShares;
        }
        // Check if the pool contain some reward
        if (currentState.currentPoolReward == 0) {
            // If it havn't any, just update the pool total shares
            currentState.totalShares = newTotalShares;
        } else {
            // Otherwise, create a new reward state
            stateIndex++;
            rewardStates[contentId][stateIndex] = RewardState({
                totalShares: newTotalShares,
                currentPoolReward: 0,
                open: true
            });
            // Update this participant shares
            currentParticipant.shares = newShares;
        }
        // TODO : If evolving from 0, set the last claimed reward to previous one
        // TODO : In all the case, ensure the user havn't reward to claim (This should fix the last point)
        // Once the pool is all set, update the participant shares
        currentParticipant.shares = newShares;
    }

    function lastContentState(uint256 contentId) internal view returns (RewardState storage state) {
        (state, ) = lastContentStateWithIndex(contentId);
    }

    function lastContentStateWithIndex(uint256 contentId)
        internal
        view
        returns (RewardState storage state, uint256 rewardIndex)
    {
        rewardIndex = currentStateIndex[contentId];
        state = rewardStates[contentId][rewardIndex];
    }
}
