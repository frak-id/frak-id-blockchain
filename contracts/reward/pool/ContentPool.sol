// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

import {FrakMath} from "../../utils/FrakMath.sol";
import {FrakRoles} from "../../utils/FrakRoles.sol";
import {FraktionTokens} from "../../tokens/FraktionTokens.sol";
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

    /**
     * @dev Add a reward inside a content pool
     */
    function addReward(uint256 contentId, uint256 rewardAmount)
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        whenNotPaused
    {
        assembly {
            if or(iszero(rewardAmount), gt(rewardAmount, MAX_REWARD)) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
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
        payable
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
     * @dev Compute all the reward for the given user
     */
    function computeAllPoolsBalance(address user) external payable onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _computeAndSaveAllForUser(user);
    }

    /**
     * @dev Withdraw the pending founds for the caller
     */
    function withdrawFounds() external virtual override whenNotPaused {
        _computeAndSaveAllForUser(msg.sender);
        _withdraw(msg.sender);
    }

    /**
     * @dev Withdraw the pending founds for a user
     */
    function withdrawFounds(address user) external virtual override onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _computeAndSaveAllForUser(user);
        _withdraw(user);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Update the participants of a pool after fraktion transfer
     */
    function updateParticipants(address from, address to, uint256 fraktionId, uint256 amountMoved) private {
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
            Participant storage sender = contentParticipants[from];
            computeAndSaveReward(contentStates, from, sender, lastContentIndex);

            // Do the same thing for the receiver
            Participant storage receiver = contentParticipants[to];
            computeAndSaveReward(contentStates, to, receiver, lastContentIndex);

            // Then update the shares for each one of them
            _increaseParticipantShare(contentId, receiver, to, uint120(totalShares));
            _decreaseParticipantShare(contentId, sender, from, uint120(totalShares));
        }
    }

    /**
     * @dev Update participant and pool after fraktion transfer
     */
    function updateParticipantAndPool(address from, address to, uint256 fraktionId, uint256 amountMoved) private {
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
            if (to != address(0)) {
                // In case of fraktions mint
                // Get the previous participant and compute his reward for this content
                Participant storage receiver = contentParticipants[to];
                computeAndSaveReward(contentRewardStates, to, receiver, stateIndex);
                // Update his shares
                _increaseParticipantShare(contentId, receiver, to, uint120(sharesMoved));
                // Update the new total shares
                newTotalShares = currentState.totalShares + sharesMoved;
            } else if (from != address(0)) {
                // In case of fraktions burn
                // Get the previous participant and compute his reward for this content
                Participant storage sender = contentParticipants[from];
                computeAndSaveReward(contentRewardStates, from, sender, stateIndex);
                // Update his shares
                _decreaseParticipantShare(contentId, sender, from, uint120(sharesMoved));
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
            }
            // Emit the pool update event
            emit PoolSharesUpdated(contentId, stateIndex, newTotalShares);
        }
    }

    /**
     * @dev Compute and save the user reward to the given state
     */
    function computeAndSaveReward(
        RewardState[] storage contentStates,
        address user,
        Participant storage participant,
        uint256 toStateIndex
    ) internal returns (uint256 claimable) {
        unchecked {
            // Replicate our participant to memory
            Participant memory memParticipant = participant;

            // Ensure the state target is not already claimed, and that we don't have too many state to fetched
            if (toStateIndex < memParticipant.lastStateIndex) {
                revert PoolStateAlreadyClaimed();
            }
            // Check the participant got some shares
            if (memParticipant.shares == 0) {
                // If not, just increase the last iterated index and return
                participant.lastStateIndex = toStateIndex;
                return 0;
            }
            // Check if he got some more reward to claim on the last state he fetched, and init our claimable reward with that
            RewardState memory memCurrentRewardState = contentStates[memParticipant.lastStateIndex];
            uint256 userReward = computeUserReward(memCurrentRewardState, memParticipant);
            claimable = userReward - memParticipant.lastStateClaim;
            // If we don't have more iteration to do, exit directly
            if (memParticipant.lastStateIndex == toStateIndex) {
                // Increase the user pending reward (if needed), and return this amount
                if (claimable > 0) {
                    // Increase the participant last state claim by the new claimable amount
                    participant.lastStateClaim = uint96(memParticipant.lastStateClaim + claimable);
                    _addFoundsUnchecked(user, claimable);
                }
                return claimable;
            }
            // Reset his last state claim if needed
            if (memParticipant.lastStateClaim != 0) {
                participant.lastStateClaim = 0;
            }

            // Then, iterate over all the states from the last states he fetched
            for (uint256 stateIndex = memParticipant.lastStateIndex + 1; stateIndex <= toStateIndex;) {
                // Get the reward state
                memCurrentRewardState = contentStates[stateIndex];
                // If we are on the last iteration, save the reward for the user
                if (stateIndex == toStateIndex) {
                    uint256 stateReward = computeUserReward(memCurrentRewardState, memParticipant);
                    claimable += stateReward;
                    // Backup his participant reward
                    participant.lastStateClaim = uint96(stateReward);
                } else {
                    // Otherwise, just compute the total reward tor this user in this state
                    claimable += computeUserReward(memCurrentRewardState, memParticipant);
                }
                ++stateIndex;
            }
            // Update the participant last state checked, and increase his pending reward
            participant.lastStateIndex = toStateIndex;
            // Update the participant claimable reward
            _addFoundsUnchecked(user, claimable);
            // Return the added claimable reward
            return claimable;
        }
    }

    /**
     * @dev Increase the share the user got in a pool
     */
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

    /**
     * @dev Decrease the share the user got in a pool
     */
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

    /**
     * @dev Compute all the reward for the given user
     */
    function _computeAndSaveAllForUser(address user) internal {
        EnumerableSet.UintSet storage contentPoolIds = userContentPools[user];
        uint256[] memory _poolsIds = userContentPools[user].values();

        uint256 length = _poolsIds.length;
        for (uint256 index = 0; index < length;) {
            // Get the content pool id and the participant and last pool id
            uint256 contentId = contentPoolIds.at(index);
            Participant storage participant = participants[contentId][user];
            // Get our content states, and the target length
            RewardState[] storage contentStates = rewardStates[contentId];
            uint256 lastPoolIndex = contentStates.length - 1;
            // Compute and save the reward for this pool
            computeAndSaveReward(contentStates, user, participant, lastPoolIndex);
            unchecked {
                ++index;
            }
        }

        // If the new reward for the user is still 0, revert (for gaz economy purposes)
        if (_pendingRewards[user] == 0) revert NoReward();
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal view function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Find only the last reward state for the given content
     */
    function lastContentState(uint256 contentId) private returns (RewardState storage state) {
        (state,) = lastContentStateWithIndex(contentId);
    }

    /**
     * @dev Find the last reward state, with it's index for the given content
     */
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
}
