// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { Initializable } from "@oz-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Upgradeable } from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { NoReward, InvalidAddress, RewardTooLarge } from "./FrakErrors.sol";

/// @author @KONFeature
/// @title IPushPullReward
/// @notice Interface for the push pull reward contracts
/// @custom:security-contact contact@frak.id
interface IPushPullReward {
    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a reward is added
    event RewardAdded(address indexed user, uint256 amount);

    /// @dev Event emitted when a user withdraw his pending reward
    event RewardWithdrawed(address indexed user, uint256 amount, uint256 fees);

    /* -------------------------------------------------------------------------- */
    /*                         External virtual function's                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev For a user to directly claim their founds
     */
    function withdrawFounds() external;

    /**
     * @dev For an admin to withdraw the founds of the given user
     */
    function withdrawFounds(address user) external;

    /* -------------------------------------------------------------------------- */
    /*                          External view function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint256);
}
