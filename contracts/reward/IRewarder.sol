// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { ContentId } from "../libs/ContentId.sol";

/// @author @KONFeature
/// @title IRewarder
/// @notice Interface for the rewarder contract
/// @custom:security-contact contact@frak.id
interface IRewarder {
    /// @dev Error throwned when the reward is invalid
    error InvalidReward();

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a user is rewarded for his listen
    event RewardOnContent(
        address indexed user, uint256 indexed contentId, uint256 baseUserReward, uint256 earningFactor
    );

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Directly pay a `listener` for the given frk `amount` (used for offchain to onchain wallet migration)
    function payUserDirectly(address listener, uint256 amount) external payable;

    /// @dev Directly pay all the creators owner of `contentIds` for each given frk `amounts` (used for offchain reward
    /// created by the user, thatis sent to the creator)
    function payCreatorDirectlyBatch(ContentId[] calldata contentIds, uint256[] calldata amounts) external payable;

    /// @dev Compute the reward for a `listener`, given the `contentType`, `contentIds` and `listenCounts`, and pay him
    /// and the owner
    function payUser(
        address listener,
        uint256 contentType,
        ContentId[] calldata contentIds,
        uint256[] calldata listenCounts
    )
        external
        payable;

    /// @dev Update the token generation factor to 'newTpu'
    function updateTpu(uint256 newTpu) external;

    /* -------------------------------------------------------------------------- */
    /*                          External view function's                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the current TPU
    function getTpu() external view returns (uint256);

    /// @dev Get the current number of FRK minted
    function getFrkMinted() external view returns (uint256);
}
