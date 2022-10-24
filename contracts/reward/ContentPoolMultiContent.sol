// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../tokens/FraktionTransferCallback.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @dev Represent our content pool contract
 * @dev TODO : Optimize uint sizes (since max supply of sybl is 3 billion e18,
 * what's the max uint we can use for the price ?, What the max array size ? So what max uint for indexes ?)
 */
/// @custom:security-contact crypto-support@sybel.co
contract ContentPoolMultiContent is FraktionTransferCallback {
    /**
     * Represent a pool reward state
     */
    struct RewardState {
        // First storage slot, remain 31 bytes
        uint128 totalShares;
        uint96 currentPoolReward;
        bool open;
    }

    /**
     * Represent a pool participant
     */
    struct Participant {
        // First storage slot, remain 40 bytes
        uint120 shares; // Number of shares in the content pool
        uint96 lastStateClaim; // The last state amount claimed
        // Second storage slot
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
     * Event emitted when a reward is added to the pool
     */
    event RewardAdded(uint256 indexed contentId, uint96 reward);

    /**
     * Event emitted when the pool shares are updated
     */
    event PoolSharesUpdated(uint256 indexed contentId, uint256 indexed poolId, uint128 totalShares);

    /**
     * Event emitted when the pool shares are updated
     */
    event PoolSharesUpdated(uint256 indexed contentId, uint128 totalShares);

    /**
     * Add a reward inside a content pool
     */
    function addReward(uint256 contentId, uint96 rewardAmount) external {
        require(rewardAmount > 0, "SYB: invalid reward");
        RewardState storage currentState = lastContentState(contentId);
        require(currentState.open, "SYB: reward state closed");
        currentState.currentPoolReward += rewardAmount;
        emit RewardAdded(contentId, rewardAmount);
    }

    /**
     * @dev called when new fraktions are transfered
     */
    function onFraktionsTransfered(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amount
    ) external override {
        if (from != address(0) && to != address(0)) {
            // Handle share transfer between participant, with no update on the total pool rewards
            for (uint256 index = 0; index < ids.length; ++index) {
                updateParticipants(from, to, ids[index], amount[index]);
            }
        } else {
            // Otherwise (in case of mined or burned token), also update the pool
            for (uint256 index = 0; index < ids.length; ++index) {
                updateParticipantAndPool(from, to, ids[index], amount[index]);
            }
        }
    }

    /**
     * Update the participants of a pool after fraktion transfer
     */
    function updateParticipants(
        address from,
        address to,
        uint256 fraktionId,
        uint256 amountMoved
    ) private {
        // Extract content id and token type from this tx
        (uint256 contentId, uint8 tokenType) = SybelMath.extractContentIdAndTokenType(fraktionId);
        // Get the initial share value of this token
        uint16 sharesValue = getSharesForTokenType(tokenType);
        if (sharesValue == 0) return; // Jump this iteration if this fraktions doesn't count for any shares
        // Get the last state index
        uint256 lastContentIndex = currentStateIndex[contentId];
        // Get the total shares moved
        uint96 totalShares = uint96(sharesValue * amountMoved);
        // Get the previous participant and compute his reward for this content
        Participant storage sender = participants[contentId][from];
        // Compute and save the reward for the participant before updating his shares
        computeAndSaveReward(contentId, from, sender, lastContentIndex);
        // Do the same thing for the receiver
        Participant storage receiver = participants[contentId][to];
        computeAndSaveReward(contentId, to, receiver, lastContentIndex);
        // Then update the shares for each one of them
        sender.shares -= totalShares;
        receiver.shares += totalShares;
    }

    /**
     * Update participant and pool after fraktion transfer
     */
    function updateParticipantAndPool(
        address from,
        address to,
        uint256 fraktionId,
        uint256 amountMoved
    ) private {
        // Extract content id and token type from this tx
        (uint256 contentId, uint8 tokenType) = SybelMath.extractContentIdAndTokenType(fraktionId);
        // Get the initial share value of this token
        uint16 sharesValue = getSharesForTokenType(tokenType);
        if (sharesValue == 0) return; // Jump this iteration if this fraktions doesn't count for any shares
        // Lock the current state for this content (since we will be updating his share)
        (RewardState storage currentState, uint256 stateIndex) = lastContentStateWithIndex(contentId);
        currentState.open = false;
        // Get the total shares moved
        uint96 sharesMoved = uint96(sharesValue * amountMoved);
        // Then update the states and participant, and save the new total shares
        uint128 newTotalShares;
        if (to != address(0)) {
            // In case of fraktions mint
            // Get the previous participant and compute his reward for this content
            Participant storage receiver = participants[contentId][to];
            computeAndSaveReward(contentId, to, receiver, stateIndex);
            // Update his shares
            receiver.shares += sharesMoved;
            // Update the new total shares
            newTotalShares = currentState.totalShares + sharesMoved;
        } else if (from != address(0)) {
            // In case of fraktions burn
            // Get the previous participant and compute his reward for this content
            Participant storage sender = participants[contentId][from];
            computeAndSaveReward(contentId, from, sender, stateIndex);
            // Update his shares
            sender.shares -= sharesMoved;
            // Update the new total shares
            newTotalShares = currentState.totalShares - sharesMoved;
        }

        // Finally, update the content pool with the new shares
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
        }
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
        // Compute and save the reward for the participant before updating his shares
        computeAndSaveReward(contentId, user, currentParticipant, stateIndex);
        // Compute the new reward state shares
        uint128 newTotalShares = currentState.totalShares + newShares - currentParticipant.shares;
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

    /**
     * @dev Compute and save the user reward to the given state
     * TODO : Max reward state to iterate over
     */
    function computeAndSaveReward(
        uint256 contentId,
        address user,
        Participant storage participant,
        uint256 toStateIndex
    ) internal returns (uint96 claimable) {
        require(user != address(0), "SYBL: invalid address");
        // Ensure the state target is not already claimed, and that we don't have too many state to fetched
        require(participant.lastStateClaim >= toStateIndex, "SYB: already claimed");
        require(
            toStateIndex - participant.lastStateIndex < MAX_CLAIMABLE_REWARD_STATE_ROUNDS,
            "SYB: too much state for computation"
        );
        // Check the participant got some shares
        if (participant.shares == 0) {
            // If not, just increase the last iterated index and return
            participant.lastStateIndex = toStateIndex;
            return 0;
        }
        // Check if he got some more reward to claim on the last state he fetched, and init our claimable reward with that
        RewardState storage lastParticipantState = rewardStates[contentId][participant.lastStateIndex];
        uint96 userReward = computeUserReward(lastParticipantState, participant);
        claimable = participant.lastStateClaim - userReward;
        // Then reset his last state claim
        participant.lastStateClaim = 0;
        // If we don't have more iteration to do, exit directly
        if (participant.lastStateIndex == toStateIndex) {
            // Increase the user pending reward (if needed), and return this amount
            if (claimable > 0) {
                userPendingReward[user] += claimable;
            }
            return claimable;
        }

        // Var used to backup the reward the user got on the last state
        uint96 lastStateReward;
        // Then, iterate over all the states from the last states he fetched
        for (uint256 stateIndex = participant.lastStateIndex + 1; stateIndex <= toStateIndex; stateIndex++) {
            // Get the reward state
            RewardState storage currentState = rewardStates[contentId][stateIndex];
            // If we are on the last iteration, save the reward
            if (stateIndex == toStateIndex) {
                lastStateReward = computeUserReward(currentState, participant);
                claimable += computeUserReward(currentState, participant);
            } else {
                // Otherwise, just compute the total reward tor this user in this state
                claimable += computeUserReward(currentState, participant);
            }
        }
        // Update the participant last state checked, and increase his pending reward
        participant.lastStateIndex = toStateIndex;
        participant.lastStateClaim = lastStateReward;
        // Update the participant claimable reward
        userPendingReward[user] += claimable;
        // Return the added claimable reward
        return claimable;
    }

    /**
     * ComputonFraktionsTransferedward in the given state
     */
    function computeUserReward(RewardState memory state, Participant memory participant)
        internal
        pure
        returns (uint96 stateReward)
    {
        stateReward = uint96((state.currentPoolReward * participant.shares) / state.totalShares);
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function getSharesForTokenType(uint8 tokenType) private pure returns (uint16 shares) {
        if (tokenType == SybelMath.TOKEN_TYPE_COMMON_MASK) {
            shares = 10;
        } else if (tokenType == SybelMath.TOKEN_TYPE_PREMIUM_MASK) {
            shares = 50;
        } else if (tokenType == SybelMath.TOKEN_TYPE_GOLD_MASK) {
            shares = 100;
        } else if (tokenType == SybelMath.TOKEN_TYPE_DIAMOND_MASK) {
            shares = 200;
        } else {
            shares = 0;
        }
        return shares;
    }
}
