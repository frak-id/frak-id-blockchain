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
contract ContentPoolReview {
    struct RewardState {
        uint256 totalShares;
        uint256 currentPoolReward;
        bool open;
    }

    struct Participant {
        uint256 shares;
        uint256 enterStateIndex;
        uint256 lastStateIndex;
        // Last withdraw timestamp ? For lock on that ? Like a claim max every 6 hours
    }

    /**
     * @dev The cap to prevent excessive gaz fees when computing user reward
     */
    uint256 private immutable MAX_CLAIMABLE_REWARD_STATE_ROUNDS = 500;

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * @dev All the different reward states (for now only shares update)
     */
    RewardState[] private rewardStates;

    /**
     * @dev The index of the current state
     */
    uint256 private currentStateIndex;

    /**
     * @dev is the state currently locked ? (processing an update, need to be locked in case of multi block tx)
     */
    bool private isStateLocked;

    /**
     * @dev Mapping between address and participant
     */
    mapping(address => Participant) private participants;

    /**
     * @dev All the reward claim by reward state index, to user addresses, to claimed reward
     */
    mapping(uint256 => mapping(address => uint256)) private claimedRewards;

    /**
     * The pending referal reward for the given address
     */
    mapping(address => uint256) private userPendingReward;

    /**
     * @dev Modifier to make a function callable only when the reward state isn't locked
     */
    modifier whenNotLocked() {
        require(!isStateLocked, "SYB: Current reward state locked");
        _;
    }

    constructor() {
        currentStateIndex = 0;
        isStateLocked = false;
    }

    /**
     * TODO : Should be able to handle reward amount directly from sybel token ??
     */
    function addReward(uint256 rewardAmount) external whenNotLocked {
        require(rewardAmount > 0, "SYB: Can't add 0 reward to the pool");
        RewardState storage currentState = rewardStates[currentStateIndex];
        require(currentState.open, "SYB: The current reward state isn't open");
        currentState.currentPoolReward += rewardAmount;
    }

    /**
     * @dev Update a participant share on this pool
     */
    function updateParticipant(address user, uint256 shares) external whenNotLocked {
        require(user != address(0), "SYBL: Can't update share on the 0 address");
        // Close the last RewardState (is it enough as lock ??)
        RewardState storage currentState = rewardStates[currentStateIndex];
        currentState.open = false;
        // Get the participant and check the share differences
        Participant storage currentParticipant = participants[user];
        require(shares != currentParticipant.shares, "SYB: Can't update share for the same share amount");
        uint256 reward = claimableReward(user);
        require(reward == 0, "SYB: User need to claim his reward before updating his position");
        // Lock the current state
        isStateLocked = true;
        // Compute the share difference
        int256 shareDifference = int256(shares - currentParticipant.shares);
        // Update this participant shares
        currentParticipant.shares = shares;
        // Compute the new reward state shares
        uint256 newTotalShares;
        if (shareDifference > 0) {
            newTotalShares += uint256(shareDifference);
        } else {
            newTotalShares -= uint256(shareDifference);
        }
        // Check if the pool contain some reward
        if (currentState.currentPoolReward == 0) {
            // If it havn't any, just update the pool total shares
            currentState.totalShares = newTotalShares;
        } else {
            // Otherwise, create a new reward state
            currentStateIndex++;
            rewardStates[currentStateIndex] = RewardState(
                newTotalShares, // total shares
                0, // current reward
                true // open state
            );
        }
        // Once we are all set, unlock the state
        isStateLocked = false;
    }

    /**
     * @dev Claim the user reward
     */
    function claimReward(address user) external whenNotLocked {
        require(user != address(0), "SYBL: Can't claim reward on the 0 address");
        // Get the participant and it's claimable reward
        Participant storage participant = participants[user];
        uint256 toBePayed = claimableReward(user);
        // Ensure the user got a claimable reward
        require(toBePayed > 0, "SYB: No reward to be claimed");
        // TODO : Have a state count cap to be able to handle edge case like long time not checked ones (cap to 200 hundred max ??)
        for (uint256 stateIndex = participant.lastStateIndex; stateIndex < currentStateIndex; stateIndex++) {
            // Get the reward the user claimed on this state
            uint256 alreadyClaimedRewards = claimedRewards[stateIndex][user];
            // Get the state
            RewardState storage state = rewardStates[stateIndex];
            // Compute the total reward tor this user in this state
            uint256 totalPoolReward = (state.currentPoolReward * participant.shares) / state.totalShares;
            toBePayed += totalPoolReward - alreadyClaimedRewards;
        }
        // Update the last handled index for the user
        participant.lastStateIndex = currentStateIndex;
        // Safe this amount for the user ?
        // Transfer from this contract to the user directly ??
        // Ensure the balance is enough
    }

    /**
     * @dev Compute the user claimable reward
     * TODO : Max reward state to iterate over
     */
    function claimableReward(address user) public returns (uint256) {
        require(user != address(0), "SYBL: Can't check the reward for the 0 address");
        // Get the participant
        Participant storage participant = participants[user];
        uint256 claimable = 0;
        uint256 lastStateIndexChecked = 0;
        require(
            currentStateIndex - participant.lastStateIndex < MAX_CLAIMABLE_REWARD_STATE_ROUNDS,
            "SYB: Trying to claim too much reward state at the same time"
        );
        // If the difference between the user claim and the last cap is too big,
        for (uint256 stateIndex = participant.lastStateIndex; stateIndex < currentStateIndex; stateIndex++) {
            // Get the reward the user claimed on this state
            uint256 alreadyClaimedRewards = claimedRewards[stateIndex][user];
            uint256 stateShare = participant.shares;
            // Get the state
            RewardState storage state = rewardStates[stateIndex];
            // Compute the total reward tor this user in this state
            uint256 totalPoolReward = (state.currentPoolReward * stateShare) / state.totalShares;
            claimable += totalPoolReward - alreadyClaimedRewards;
            // Update our last index iterated
            lastStateIndexChecked = stateIndex;
        }
        // Update the participant last state checked, and increase his pending reward
        participant.lastStateIndex = lastStateIndexChecked;
        userPendingReward[user] += claimable;
        // Return the added claimable reward
        return claimable;
    }

    /**
     * Compute the number of states this participant can claim
     */
    function statesToClaim(Participant storage participant) private view returns (uint256) {}
}
