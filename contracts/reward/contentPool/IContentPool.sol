// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionTransferCallback } from "../../fraktions/FraktionTransferCallback.sol";
import { ContentId } from "../../lib/ContentId.sol";

/// @author @KONFeature
/// @title IContentPool
/// @notice Interface for the content pool contract
/// @custom:security-contact contact@frak.id
interface IContentPool is FraktionTransferCallback {
    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev The pool state is closed
    error PoolStateClosed();

    /// @dev When the user already claimed this pool state
    error PoolStateAlreadyClaimed();

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a reward is added to the pool
    event PoolRewardAdded(uint256 indexed contentId, uint256 reward);

    /// @dev Event emitted when the pool shares are updated
    event PoolSharesUpdated(uint256 indexed contentId, uint256 indexed poolId, uint256 totalShares);

    /// @dev Event emitted when participant share are updated
    event ParticipantShareUpdated(address indexed user, uint256 indexed contentId, uint256 shares);

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
        bool open; // pos : 0x01 + 0x1C -> 0x1C <-> 0x1D ? Or less since multiple value can be packed inside a single
            // slot ?
    }

    /**
     * @dev Represent a pool participant
     */
    struct Participant {
        // First storage slot, remain 40 bytes
        uint120 shares; // Number of shares in the content pool, pos :  0x0 <-> 0x0F
        uint96 lastStateClaim; // The last state amount claimed, pos : 0x0F + 0x0C -> 0x0F <-> 0x1B
        // Second storage slot
        uint256 lastStateIndex; // What was the last state index he claimed in the pool ? -> TODO : 0x20 or Ox1B ->
            // (0x0F + 0x0C)
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
    /*                          External write funtion's                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Add a new `rewardAmount` to the pool for the content `contentId`
    function addReward(ContentId contentId, uint256 rewardAmount) external payable;

    /// @dev Compute all the pools balance of the user
    function computeAllPoolsBalance(address user) external payable;

    /* -------------------------------------------------------------------------- */
    /*                          External view function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Get the current reward state for the given content
     */
    function getAllRewardStates(uint256 contentId) external view returns (RewardState[] memory _rewardStates);

    /**
     * @dev Get the current participant state for the given content
     */
    function getParticipantForContent(
        uint256 contentId,
        address user
    )
        external
        view
        returns (Participant memory participant);

    /**
     * @dev Get all the user pools with the current state
     */
    function getParticipantStates(address user)
        external
        view
        returns (ParticipantInPoolState[] memory participantStateInPool);
}
