// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {FraktionTransferCallback} from "../../tokens/FraktionTransferCallback.sol";
import {PushPullReward} from "../../utils/PushPullReward.sol";
import {FrakAccessControlUpgradeable} from "../../utils/FrakAccessControlUpgradeable.sol";
import {InvalidAddress, NoReward} from "../../utils/FrakErrors.sol";
import {EnumerableSet} from "openzeppelin/utils/structs/EnumerableSet.sol";

/**
 * @author  @KONFeature
 * @title   ContentPool
 * @dev     Represent our content pool contract
 * @custom:security-contact contact@frak.id
 */
contract ContentPool is FrakAccessControlUpgradeable, PushPullReward, FraktionTransferCallback {
    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev The pool state is closed
    error PoolStateClosed();

    /// @dev When the user already claimed this pool state
    error PoolStateAlreadyClaimed();

    /// @dev 'bytes4(keccak256(bytes("NoReward()")))'
    uint256 private constant _NO_REWARD_SELECTOR = 0x6e992686;

    /// @dev 'bytes4(keccak256(bytes("PoolStateClosed()")))'
    uint256 private constant _POOL_STATE_CLOSED_SELECTOR = 0xc43057c1;

    /// @dev 'bytes4(keccak256(bytes("PoolStateAlreadyClaimed()")))'
    uint256 private constant _POOL_STATE_ALREADY_CLAIMED_SELECTOR = 0xa917cd37;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a reward is added to the pool
    event PoolRewardAdded(uint256 indexed contentId, uint256 reward);

    /// @dev Event emitted when the pool shares are updated
    event PoolSharesUpdated(uint256 indexed contentId, uint256 indexed poolId, uint256 totalShares);

    /// @dev Event emitted when participant share are updated
    event ParticipantShareUpdated(address indexed user, uint256 indexed contentId, uint256 shares);

    /// @dev 'keccak256(bytes("PoolRewardAdded(uint256,uint256)"))'
    uint256 private constant _POOL_REWARD_ADDED_EVENT_SELECTOR =
        0xdb778ef6a08c77e60fdae7e0f8797546f4313672de2bafc3b582b6262916009e;

    /// @dev 'keccak256(bytes("PoolSharesUpdated(uint256,uint256,uint256)"))'
    uint256 private constant _POOL_SHARES_UPDATED_EVENT_SELECTED =
        0x3905a45038235a94849680d9f38785ce7eaa5ad913bc44a390332a3791f9eb9a;

    /// @dev 'keccak256(bytes("ParticipantSharesUpdated(uint256,uint256,uint256)"))'
    uint256 private constant _PARTICIPANT_SHARES_UPDATED_EVENT_SELECTED =
        0x1ecb16c5f7a5b459071d87585a22f39d1e567f4c0406de6e4b654a4c74b0908b;

    /* -------------------------------------------------------------------------- */
    /*                                 Constant's                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Maximum reward we can have in a pool
    uint256 private constant MAX_REWARD = 100_000 ether;

    /* -------------------------------------------------------------------------- */
    /*                                  Struct's                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Represent a pool reward state
     */
    struct RewardState {
        // First storage slot, remain 31 bytes (if bool encoded inside a single byte)
        uint128 totalShares; // pos : 0x0 <-> 0x10
        uint96 currentPoolReward; // pos : 0x10 + 0x0C -> 0x10 <-> 0x1C
        bool open; // pos : 0x01 + 0x1C -> 0x1C <-> 0x1D ? Or less since multiple value can be packed inside a single slot ?
    }

    /**
     * @dev Represent a pool participant
     */
    struct Participant {
        // First storage slot, remain 40 bytes
        uint120 shares; // Number of shares in the content pool, pos :  0x0 <-> 0x0F
        uint96 lastStateClaim; // The last state amount claimed, pos : 0x0F + 0x0C -> 0x0F <-> 0x1B
        // Second storage slot
        uint256 lastStateIndex; // What was the last state index he claimed in the pool ? -> TODO : 0x20 or Ox1B -> (0x0F + 0x0C)
    }

    /**
     * @dev Represent the participant state in a pool
     * @dev Only used for view function! Heavy object that shouldn't be stored in storage
     */
    struct ParticipantInPoolState {
        // Pool info's
        uint256 poolId;
        uint256 totalShares; // The total shares of the pool at the last state
        uint256 poolState; // The index of the current pool state
        // Participant info's
        uint256 shares;
        uint256 lastStateClaimed; // The last state amount claimed for the given pool
        uint256 lastStateIndex; // The index of the last state a participant claimed in a pool
        uint256 lastStateClaimable; // The claimable amount for the participant in the given pool
    }

    /**
     * @dev In memory accounter for the balance claimable update post transfer
     */
    struct FraktionTransferAccounter {
        address from;
        uint256 deltaFrom;
        address to;
        uint256 deltaTo;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The index of the current state index per content
    /// TODO : This is unused now since we use the array length (more effecient since we perform a first sload on the mapping, and we need to do it anyway)
    mapping(uint256 => uint256) private currentStateIndex;

    /// @dev All the different reward states per content id
    mapping(uint256 => RewardState[]) private rewardStates;

    /// @dev Mapping between content id, to address to participant
    mapping(uint256 => mapping(address => Participant)) private participants;

    /// @dev User address to list of content pool he is in
    mapping(address => EnumerableSet.UintSet) private userContentPools;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr) external initializer {
        if (frkTokenAddr == address(0)) revert InvalidAddress();

        // Only for v1 deployment
        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(frkTokenAddr);

        // Current version is 2, since we use a version to reset a user fcked up pending reward
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write funtion's                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Add a new `rewardAmount` to the pool for the content `contentId`
    function addReward(uint256 contentId, uint256 rewardAmount)
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        whenNotPaused
    {
        // Ensure reward is specified
        assembly ("memory-safe") {
            if or(iszero(rewardAmount), gt(rewardAmount, MAX_REWARD)) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        // Get the current state
        RewardState storage currentState = lastContentState(contentId);
        if (!currentState.open) revert PoolStateClosed();

        // Increase the reward
        unchecked {
            currentState.currentPoolReward += uint96(rewardAmount);
        }

        // Send the event
        emit PoolRewardAdded(contentId, rewardAmount);
    }

    /// @dev Callback from the erc1155 tokens when fraktion are transfered
    function onFraktionsTransferred(address from, address to, uint256[] memory ids, uint256[] memory amount)
        external
        payable
        override
        onlyRole(FrakRoles.TOKEN_CONTRACT)
    {
        // Create our update accounter
        FraktionTransferAccounter memory accounter =
            FraktionTransferAccounter({from: from, deltaFrom: 0, to: to, deltaTo: 0});

        if (from != address(0) && to != address(0)) {
            // Handle share transfer between participant, with no update on the total pool rewards
            for (uint256 index; index < ids.length;) {
                updateParticipants(accounter, ids[index], amount[index]);
                unchecked {
                    ++index;
                }
            }
        } else {
            // Otherwise (in case of mined or burned token), also update the pool
            for (uint256 index; index < ids.length;) {
                updateParticipantAndPool(accounter, ids[index], amount[index]);
                unchecked {
                    ++index;
                }
            }
        }

        // Save the founds update if needed
        if (accounter.deltaFrom > 0) {
            _addFounds(from, accounter.deltaFrom);
        }
        if (accounter.deltaTo > 0) {
            _addFounds(to, accounter.deltaTo);
        }
    }

    /// @dev Compute all the pools balance of the user
    function computeAllPoolsBalance(address user) external payable onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _computeAndSaveAllForUser(user);
    }

    /// @dev Withdraw the pending founds for the current caller
    function withdrawFounds() external virtual override whenNotPaused {
        _computeAndSaveAllForUser(msg.sender);
        _tryWithdraw(msg.sender);
    }

    /// @dev Withdraw the pending founds for a `user`
    function withdrawFounds(address user) external virtual override onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _computeAndSaveAllForUser(user);
        _tryWithdraw(user);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the participants of a pool after fraktion transfer
     */
    function updateParticipants(FraktionTransferAccounter memory accounter, uint256 fraktionId, uint256 amountMoved)
        private
    {
        unchecked {
            // Extract content id and token type from this tx
            (uint256 contentId, uint256 tokenType) = FrakMath.extractContentIdAndTokenType(fraktionId);

            // Get the initial share value of this token
            uint256 sharesValue = getSharesForTokenType(tokenType);
            if (sharesValue == 0) return; // Jump this iteration if this fraktions doesn't count for any shares

            // Get the last state index
            RewardState[] storage contentStates = rewardStates[contentId];
            uint256 lastContentIndex = contentStates.length - 1;

            // Get the total shares moved
            uint256 totalShares = sharesValue * amountMoved;

            // Warm up the access to this content participants
            mapping(address => Participant) storage contentParticipants = participants[contentId];

            // Get the previous participant and compute his reward for this content
            Participant storage sender = contentParticipants[accounter.from];
            uint256 delta = _computeAllPendingParticipantStates(contentStates, sender, lastContentIndex);
            accounter.deltaFrom += delta;

            // TODO: Find a way to compute the delta from the receiver, taking in account the edge case where the receiver has multiple content pool
            // TODO: In memory hashmap of the shares movement per content id?
            Participant storage receiver = contentParticipants[accounter.to];

            // Then update the shares for each one of them
            _decreaseParticipantShare(contentId, sender, accounter.from, uint120(totalShares));
            _increaseParticipantShare(contentId, receiver, accounter.to, uint120(totalShares));

            // Reset the receiver status
            _resetParticipantState(contentStates, receiver);
        }
    }

    /**
     * @dev Update participant and pool after fraktion transfer
     */
    function updateParticipantAndPool(
        FraktionTransferAccounter memory accounter,
        uint256 fraktionId,
        uint256 amountMoved
    ) private {
        unchecked {
            // Extract content id and token type from this tx
            (uint256 contentId, uint256 tokenType) = FrakMath.extractContentIdAndTokenType(fraktionId);
            // Get the total shares moved
            uint256 sharesMoved = getSharesForTokenType(tokenType) * amountMoved;
            if (sharesMoved == 0) return; // Jump this iteration if this fraktions doesn't count for any shares

            // Get the mapping and array concerned by this content (warm up further access)
            mapping(address => Participant) storage contentParticipants = participants[contentId];
            RewardState[] storage contentRewardStates = rewardStates[contentId];
            // If state index is at 0, we perform state creation directly
            RewardState storage currentState;
            uint256 stateIndex;
            if (contentRewardStates.length == 0) {
                currentState = contentRewardStates.push();
                stateIndex = 0;
            } else {
                stateIndex = contentRewardStates.length - 1;
                currentState = contentRewardStates[stateIndex];
            }
            // Tell it's closed, really necessary ?
            currentState.open = false;
            // Then update the states and participant, and save the new total shares
            uint256 newTotalShares;
            if (accounter.to != address(0)) {
                // In case of fraktions mint
                // Get the previous participant and compute his reward for this content
                Participant storage receiver = contentParticipants[accounter.to];
                accounter.deltaTo += _computeAllPendingParticipantStates(contentRewardStates, receiver, stateIndex);
                // Update his shares
                _increaseParticipantShare(contentId, receiver, accounter.to, uint120(sharesMoved));
                // Update the new total shares
                newTotalShares = currentState.totalShares + sharesMoved;
            } else if (accounter.from != address(0)) {
                // In case of fraktions burn
                // Get the previous participant and compute his reward for this content
                Participant storage sender = contentParticipants[accounter.from];
                accounter.deltaFrom += _computeAllPendingParticipantStates(contentRewardStates, sender, stateIndex);
                // Update his shares
                _decreaseParticipantShare(contentId, sender, accounter.from, uint120(sharesMoved));
                // Update the new total shares
                newTotalShares = currentState.totalShares - sharesMoved;
            }

            // Finally, update the content pool with the new shares
            if (currentState.currentPoolReward == 0 || currentState.totalShares == 0) {
                // If it havn't any, just update the pool total shares and reopen it
                // Or if we havn't any shares on this state (at init for example)
                currentState.totalShares = uint128(newTotalShares);
                currentState.open = true;
            } else {
                // Otherwise, create a new reward state
                RewardState storage newState = contentRewardStates.push();
                newState.totalShares = uint128(newTotalShares);
                newState.open = true;
                // And we reset users states
                if (accounter.to != address(0)) {
                    _resetParticipantState(contentRewardStates, contentParticipants[accounter.to]);
                } else if (accounter.from != address(0)) {
                    _resetParticipantState(contentRewardStates, contentParticipants[accounter.from]);
                }
            }

            // Emit the pool update event
            emit PoolSharesUpdated(contentId, stateIndex, newTotalShares);
        }
    }

    /// @dev Compute all the pending participant states
    /// @dev Will compute all the pending states for a participant and update his last state claimed
    /// @param contentStates The reward states of the content
    /// @param participant The participant to compute the states for
    /// @param toStateIndex The index of the last state to compute
    /// @return claimable The total amount of claimable tokens
    function _computeAllPendingParticipantStates(
        RewardState[] storage contentStates,
        Participant storage participant,
        uint256 toStateIndex
    ) internal returns (uint256 claimable) {
        // Replicate our participant to memory
        Participant memory memParticipant = participant;

        // Ensure we are targetting a state that exist after the last state claimed by the user
        if (memParticipant.lastStateIndex > toStateIndex) {
            revert PoolStateAlreadyClaimed();
        }

        // If the participant has no shares currently, update his last state claimed and exit directly
        if (memParticipant.shares == 0) {
            participant.lastStateIndex = toStateIndex;
            participant.lastStateClaim = 0;
            return 0;
        }

        // The state we will check
        RewardState memory memCurrentRewardState;

        // Iterate over every state from the last one claimed by the user to the targetted one
        for (uint256 i = memParticipant.lastStateIndex; i <= toStateIndex;) {
            // Get the current state
            memCurrentRewardState = contentStates[i];
            // Compute the user reward for this state
            uint256 userReward = computeUserReward(memCurrentRewardState, memParticipant);

            // If we are on the last iteration, set the user last state claim to the current state reward
            if (i == toStateIndex && memParticipant.lastStateClaim < userReward) {
                participant.lastStateClaim = uint96(userReward);
            }

            // If we are on the last state that was claimed, deduce the last claim from the user reward
            if (i == memParticipant.lastStateIndex && memParticipant.lastStateClaim > 0) {
                if (userReward > memParticipant.lastStateClaim) {
                    // If the reward is greater than the last claim, we can deduce it
                    // @warning: Since we are using the memory participant, it doesn't has been updated with the value on top, so we decrease only the last claim if we are in the case of lastIndextoClaim == lastParticipantIndex
                    userReward -= memParticipant.lastStateClaim;
                } else {
                    // Otherwise, the user has already claimed this state, so we can set the reward to 0
                    userReward = 0;
                }
            }

            // Update the user claimable reward
            unchecked {
                claimable += userReward;
                ++i;
            }
        }

        // Update the participant last state checked, and increase his pending reward
        unchecked {
            participant.lastStateIndex = toStateIndex;
        }
    }

    /// @dev Increase the share the `user` got in a pool of `contentId`by `amount`
    function _increaseParticipantShare(uint256 contentId, Participant storage participant, address user, uint120 amount)
        private
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

    /// @dev Decrease the share the `user` got in a pool of `contentId`by `amount`
    function _decreaseParticipantShare(uint256 contentId, Participant storage participant, address user, uint120 amount)
        private
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

    /// @dev Compute all the reward for the given `user`
    function _computeAndSaveAllForUser(address user) internal {
        EnumerableSet.UintSet storage contentPoolIds = userContentPools[user];
        uint256[] memory _poolsIds = userContentPools[user].values();

        uint256 length = _poolsIds.length;
        uint256 totalClaimable;
        for (uint256 index = 0; index < length;) {
            // Get the content pool id and the participant and last pool id
            uint256 contentId = contentPoolIds.at(index);
            Participant storage participant = participants[contentId][user];
            // Get our content states, and the target length
            RewardState[] storage contentStates = rewardStates[contentId];
            uint256 lastPoolIndex = contentStates.length - 1;
            // Compute and save the reward for this pool
            totalClaimable += _computeAllPendingParticipantStates(contentStates, participant, lastPoolIndex);
            unchecked {
                ++index;
            }
        }

        // Add the computed founds
        _addFoundsUnchecked(user, totalClaimable);
    }

    /// @dev Reset a participant state to the last reward state
    function _resetParticipantState(RewardState[] storage contentStates, Participant storage participant) private {
        // Get the last content state index
        uint256 lastContentStateIndex = contentStates.length - 1;
        // Reset the participant state
        participant.lastStateIndex = lastContentStateIndex;
        participant.lastStateClaim = uint96(computeUserReward(contentStates[lastContentStateIndex], participant));
    }

    /// @dev Get the latest content `state` for the given `contentId`
    function lastContentState(uint256 contentId) private returns (RewardState storage state) {
        (state,) = lastContentStateWithIndex(contentId);
    }

    /// @dev Get the latest content `state` and `index` for the given `contentId`
    function lastContentStateWithIndex(uint256 contentId)
        private
        returns (RewardState storage state, uint256 rewardIndex)
    {
        // Ensure we got a state, otherwise create the first one
        RewardState[] storage contentRewardStates = rewardStates[contentId];
        if (contentRewardStates.length == 0) {
            // In the case of direct creation, mark it as open
            state = contentRewardStates.push();
            state.open = true;
        } else {
            // Otherwise, get the current index and get it
            rewardIndex = contentRewardStates.length - 1;
            state = contentRewardStates[rewardIndex];
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal pure function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Compute the user reward at the given state
     */
    function computeUserReward(RewardState memory state, Participant memory participant)
        internal
        pure
        returns (uint256 stateReward)
    {
        // Directly exit if this state doesn't have a total share
        uint256 totalShares = state.totalShares;
        if (totalShares == 0) return 0;

        // We can safely do an unchecked operation here since the pool reward, participant shares and total shares are all verified before being stored
        unchecked {
            stateReward = (state.currentPoolReward * participant.shares) / totalShares;
        }
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function getSharesForTokenType(uint256 tokenType) private pure returns (uint256 shares) {
        if (tokenType == FrakMath.TOKEN_TYPE_COMMON_MASK) {
            shares = 10;
        } else if (tokenType == FrakMath.TOKEN_TYPE_PREMIUM_MASK) {
            shares = 50;
        } else if (tokenType == FrakMath.TOKEN_TYPE_GOLD_MASK) {
            shares = 100;
        } else if (tokenType == FrakMath.TOKEN_TYPE_DIAMOND_MASK) {
            shares = 200;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          External view function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Get the current reward state for the given content
     */
    function getAllRewardStates(uint256 contentId) external view returns (RewardState[] memory _rewardStates) {
        _rewardStates = rewardStates[contentId];
    }

    /**
     * @dev Get the current participant state for the given content
     */
    function getParticipantForContent(uint256 contentId, address user)
        external
        view
        returns (Participant memory participant)
    {
        participant = participants[contentId][user];
    }

    /**
     * @dev Get all the user pools with the current state
     */
    function getParticipantStates(address user)
        external
        view
        returns (ParticipantInPoolState[] memory participantStateInPool)
    {
        // Get all the user pool
        EnumerableSet.UintSet storage contentPoolIds = userContentPools[user];
        uint256[] memory _poolsIds = userContentPools[user].values();

        // Cache the array length
        uint256 length = _poolsIds.length;

        // Init our return array
        participantStateInPool = new ParticipantInPoolState[](_poolsIds.length);

        for (uint256 index = 0; index < length;) {
            // Get the content pool id and the participant and last pool id
            uint256 contentId = contentPoolIds.at(index);
            Participant storage participant = participants[contentId][user];

            // Get our content states, and the target length
            RewardState[] storage contentStates = rewardStates[contentId];
            uint256 lastPoolIndex = contentStates.length - 1;

            // Compute the amount the user can claim on this pool state
            uint256 lastStateClaimable = computeUserReward(contentStates[lastPoolIndex], participant);
            if (lastPoolIndex == participant.lastStateIndex) {
                lastStateClaimable -= participant.lastStateClaim;
            }

            // Push the infos for the pool
            participantStateInPool[index] = ParticipantInPoolState({
                poolId: contentId,
                totalShares: contentStates[lastPoolIndex].totalShares,
                poolState: lastPoolIndex,
                shares: participant.shares,
                lastStateClaimed: participant.lastStateClaim,
                lastStateIndex: participant.lastStateIndex,
                lastStateClaimable: lastStateClaimable
            });

            // Compute and save the reward for this pool
            unchecked {
                ++index;
            }
        }
    }
}
