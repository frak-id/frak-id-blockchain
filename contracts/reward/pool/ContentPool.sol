// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {FraktionTokens} from "../../tokens/FraktionTokens.sol";
import {FraktionTransferCallback} from "../../tokens/FraktionTransferCallback.sol";
import {PushPullReward} from "../../utils/PushPullReward.sol";
import {FrakAccessControlUpgradeable} from "../../utils/FrakAccessControlUpgradeable.sol";
import {InvalidAddress, NoReward} from "../../utils/FrakErrors.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @dev The pool state is closed
error PoolStateClosed();
/// @dev When the user already claimed this pool state
error PoolStateAlreadyClaimed();

/**
 * @dev Represent our content pool contract
 * @dev TODO : Optimize uint sizes (since max supply of frk is 3 billion e18,
 * what's the max uint we can use for the price ?, What the max array size ? So what max uint for indexes ?)
 */
/// @custom:security-contact contact@frak.id
contract ContentPool is FrakAccessControlUpgradeable, PushPullReward, FraktionTransferCallback {
    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private constant MAX_REWARD = 100_000 ether; // The max reward we can have in a pool

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
     * @dev The index of the current state index per content
     */
    mapping(uint256 => uint256) private currentStateIndex;

    /**
     * @dev All the different reward states per content id
     */
    mapping(uint256 => RewardState[]) private rewardStates;

    /**
     * @dev Mapping between content id, to address to participant
     */
    mapping(uint256 => mapping(address => Participant)) private participants;

    /**
     * User address to list of content pool he is in
     */
    mapping(address => EnumerableSet.UintSet) private userContentPools;

    /**
     * Event emitted when a reward is added to the pool
     */
    event PoolRewardAdded(uint256 indexed contentId, uint256 reward);

    /**
     * Event emitted when the pool shares are updated
     */
    event PoolSharesUpdated(uint256 indexed contentId, uint256 indexed poolId, uint256 totalShares);

    /**
     * Event emitted when participant share are updated
     */
    event ParticipantShareUpdated(address indexed user, uint256 indexed contentId, uint256 shares);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr) external initializer {
        if (frkTokenAddr == address(0)) revert InvalidAddress();

        // Only for v1 deployment
        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(frkTokenAddr);
    }

    /**
     * Add a reward inside a content pool
     */
    function addReward(uint256 contentId, uint256 rewardAmount) external onlyRole(FrakRoles.REWARDER) whenNotPaused {
        if (rewardAmount == 0 || rewardAmount > MAX_REWARD) revert NoReward();
        RewardState storage currentState = lastContentState(contentId);
        if (!currentState.open) revert PoolStateClosed();
        unchecked {
            currentState.currentPoolReward += uint96(rewardAmount);
        }
        emit PoolRewardAdded(contentId, rewardAmount);
    }

    /**
     * @dev called when new fraktions are transfered
     */
    function onFraktionsTransferred(address from, address to, uint256[] memory ids, uint256[] memory amount)
        external
        override
        onlyRole(FrakRoles.TOKEN_CONTRACT)
    {
        if (from != address(0) && to != address(0)) {
            // Handle share transfer between participant, with no update on the total pool rewards
            for (uint256 index; index < ids.length;) {
                updateParticipants(from, to, ids[index], amount[index]);
                unchecked {
                    ++index;
                }
            }
        } else {
            // Otherwise (in case of mined or burned token), also update the pool
            for (uint256 index; index < ids.length;) {
                updateParticipantAndPool(from, to, ids[index], amount[index]);
                unchecked {
                    ++index;
                }
            }
        }
    }

    /**
     * Update the participants of a pool after fraktion transfer
     */
    function updateParticipants(address from, address to, uint256 fraktionId, uint256 amountMoved) private {
        // Extract content id and token type from this tx
        (uint256 contentId, uint8 tokenType) = FrakMath.extractContentIdAndTokenType(fraktionId);
        // Get the initial share value of this token
        uint256 sharesValue = getSharesForTokenType(tokenType);
        if (sharesValue == 0) return; // Jump this iteration if this fraktions doesn't count for any shares
        // Get the last state index
        uint256 lastContentIndex = currentStateIndex[contentId];
        // Get the total shares moved
        uint120 totalShares = uint120(sharesValue * amountMoved);
        // Warm up the access to this content participants
        mapping(address => Participant) storage contentParticipants = participants[contentId];

        // Get the previous participant and compute his reward for this content
        Participant storage sender = contentParticipants[from];
        computeAndSaveReward(contentId, from, sender, lastContentIndex);

        // Do the same thing for the receiver
        Participant storage receiver = contentParticipants[to];
        computeAndSaveReward(contentId, to, receiver, lastContentIndex);

        // Then update the shares for each one of them
        _increaseParticipantShare(contentId, receiver, to, totalShares);
        _decreaseParticipantShare(contentId, sender, from, totalShares);
    }

    /**
     * Update participant and pool after fraktion transfer
     */
    function updateParticipantAndPool(address from, address to, uint256 fraktionId, uint256 amountMoved) private {
        // Extract content id and token type from this tx
        (uint256 contentId, uint8 tokenType) = FrakMath.extractContentIdAndTokenType(fraktionId);
        // Get the total shares moved
        uint120 sharesMoved = uint120(getSharesForTokenType(tokenType) * amountMoved);
        if (sharesMoved == 0) return; // Jump this iteration if this fraktions doesn't count for any shares

        // Get the mapping and array concerned by this content (warm up further access)
        mapping(address => Participant) storage contentParticipants = participants[contentId];
        RewardState[] storage contentRewardStates = rewardStates[contentId];
        // Lock the current state for this content (since we will be updating his share)
        uint256 stateIndex = currentStateIndex[contentId];
        // If state index is at 0, we perform state creation directly
        RewardState storage currentState;
        if (contentRewardStates.length == 0) {
            currentState = contentRewardStates.push();
        } else {
            currentState = contentRewardStates[stateIndex];
        }
        currentState.open = false;
        // Then update the states and participant, and save the new total shares
        uint256 newTotalShares;
        if (to != address(0)) {
            // In case of fraktions mint
            // Get the previous participant and compute his reward for this content
            Participant storage receiver = contentParticipants[to];
            computeAndSaveReward(contentId, to, receiver, stateIndex);
            // Update his shares
            _increaseParticipantShare(contentId, receiver, to, sharesMoved);
            // Update the new total shares
            newTotalShares = currentState.totalShares + sharesMoved;
        } else if (from != address(0)) {
            // In case of fraktions burn
            // Get the previous participant and compute his reward for this content
            Participant storage sender = contentParticipants[from];
            computeAndSaveReward(contentId, from, sender, stateIndex);
            // Update his shares
            _decreaseParticipantShare(contentId, sender, from, sharesMoved);
            // Update the new total shares
            newTotalShares = currentState.totalShares - sharesMoved;
        }

        // Finally, update the content pool with the new shares
        if (currentState.currentPoolReward == 0) {
            // If it havn't any, just update the pool total shares and reopen it
            currentState.totalShares = uint128(newTotalShares);
            currentState.open = true;
        } else {
            // Otherwise, create a new reward state
            contentRewardStates.push(
                RewardState({totalShares: uint128(newTotalShares), currentPoolReward: 0, open: true})
            );
            currentStateIndex[contentId] = contentRewardStates.length - 1;
        }
        // Emit the pool update event
        emit PoolSharesUpdated(contentId, stateIndex, newTotalShares);
    }

    /**
     * Increase the share the user got in a pool
     */
    function _increaseParticipantShare(uint256 contentId, Participant storage participant, address user, uint120 amount)
        internal
    {
        // Add this pool to the user participating pool if he have 0 shares before
        if (participant.shares == 0) {
            userContentPools[user].add(contentId);
        }
        // Increase his share
        unchecked {
            participant.shares += amount;
        }
        // Emit the update event
        emit ParticipantShareUpdated(user, contentId, participant.shares);
    }

    /**
     * Decrease the share the user got in a pool
     */
    function _decreaseParticipantShare(uint256 contentId, Participant storage participant, address user, uint120 amount)
        internal
    {
        // Decrease his share
        unchecked {
            participant.shares -= amount;
        }
        // If he know have 0 shares, remove it from the pool
        if (participant.shares == 0) {
            userContentPools[user].remove(contentId);
        }
        // Emit the update event
        emit ParticipantShareUpdated(user, contentId, participant.shares);
    }

    /**
     * Find only the last reward state for the given content
     */
    function lastContentState(uint256 contentId) internal returns (RewardState storage state) {
        (state,) = lastContentStateWithIndex(contentId);
    }

    /**
     * Find the last reward state, with it's index for the given content
     */
    function lastContentStateWithIndex(uint256 contentId)
        internal
        returns (RewardState storage state, uint256 rewardIndex)
    {
        rewardIndex = currentStateIndex[contentId];
        // Ensure we got a state, otherwise create the first one
        RewardState[] storage contentRewardStates = rewardStates[contentId];
        if (contentRewardStates.length == 0) {
            state = contentRewardStates.push();
            // In the case of direct creation, mark it as open
            state.open = true;
        } else {
            state = contentRewardStates[rewardIndex];
        }
    }

    /**
     * @dev Compute and save the user reward to the given state
     */
    function computeAndSaveReward(
        uint256 contentId,
        address user,
        Participant storage participant,
        uint256 toStateIndex
    ) internal returns (uint256 claimable) {
        // Replicate our participant to memory
        Participant memory _participant = participant;

        // Ensure the state target is not already claimed, and that we don't have too many state to fetched
        if (toStateIndex < _participant.lastStateIndex) revert PoolStateAlreadyClaimed();
        // Check the participant got some shares
        if (_participant.shares == 0) {
            // If not, just increase the last iterated index and return
            participant.lastStateIndex = toStateIndex;
            return 0;
        }
        // Check if he got some more reward to claim on the last state he fetched, and init our claimable reward with that
        RewardState[] storage contentStates = rewardStates[contentId];
        RewardState memory currentState = contentStates[_participant.lastStateIndex];
        uint256 userReward = computeUserReward(currentState, _participant);
        unchecked {
            claimable = userReward - _participant.lastStateClaim;
        }
        // Then reset his last state claim if needed
        if (_participant.lastStateClaim != 0) {
            participant.lastStateClaim = 0;
        }
        // If we don't have more iteration to do, exit directly
        if (_participant.lastStateIndex == toStateIndex) {
            // Increase the user pending reward (if needed), and return this amount
            if (claimable > 0) {
                _addFoundsUnchecked(user, claimable);
            }
            return claimable;
        }

        // Var used to backup the reward the user got on the last state
        uint256 lastStateReward;
        // Then, iterate over all the states from the last states he fetched
        for (uint256 stateIndex = _participant.lastStateIndex + 1; stateIndex <= toStateIndex;) {
            // Get the reward state
            currentState = contentStates[stateIndex];
            unchecked {
                // If we are on the last iteration, save the reward
                if (stateIndex == toStateIndex) {
                    lastStateReward = computeUserReward(currentState, _participant);
                    claimable += lastStateReward;
                } else {
                    // Otherwise, just compute the total reward tor this user in this state
                    claimable += computeUserReward(currentState, _participant);
                }
                ++stateIndex;
            }
        }
        // Update the participant last state checked, and increase his pending reward
        participant.lastStateIndex = toStateIndex;
        participant.lastStateClaim = uint96(lastStateReward);
        // Update the participant claimable reward
        _addFoundsUnchecked(user, claimable);
        // Return the added claimable reward
        return claimable;
    }

    /**
     * ComputonFraktionsTransferedward in the given state
     */
    function computeUserReward(RewardState memory state, Participant memory participant)
        internal
        pure
        returns (uint256 stateReward)
    {
        // We can safely do an unchecked operation here since the pool reward, participant shares and total shares are all verified before being stored
        unchecked {
            stateReward = (state.currentPoolReward * participant.shares) / state.totalShares;
        }
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function getSharesForTokenType(uint8 tokenType) private pure returns (uint256 shares) {
        assembly {
            switch tokenType
            case 3 {
                // common
                shares := 10
            }
            case 4 {
                // premium
                shares := 50
            }
            case 5 {
                // gold
                shares := 100
            }
            case 6 {
                // diamond
                shares := 200
            }
            default { shares := 0 }
        }
    }

    /**
     * Compute all the reward for the given user
     */
    function _computeAndSaveAllForUser(address user) internal {
        EnumerableSet.UintSet storage contentPoolIds = userContentPools[user];
        uint256[] memory _poolsIds = userContentPools[user].values();

        for (uint256 index = 0; index < _poolsIds.length; ++index) {
            // Get the content pool id and the participant and last pool id
            uint256 contentId = contentPoolIds.at(index);
            Participant storage participant = participants[contentId][user];
            uint256 lastPoolIndex = currentStateIndex[contentId];
            // Compute and save the reward for this pool
            computeAndSaveReward(contentId, user, participant, lastPoolIndex);
        }

        // If the new reward for the user is still 0, revert
        if (_pendingRewards[user] == 0) revert NoReward();
    }

    /**
     * Compute all the reward for the given user
     */
    function computeAllPoolsBalance(address user) external onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _computeAndSaveAllForUser(user);
    }

    function withdrawFounds() external virtual override whenNotPaused {
        _computeAndSaveAllForUser(msg.sender);
        _withdraw(msg.sender);
    }

    function withdrawFounds(address user) external virtual override onlyRole(FrakRoles.ADMIN) whenNotPaused {
        if (user == address(0)) revert InvalidAddress();
        _computeAndSaveAllForUser(user);
        _withdraw(user);
    }
}
