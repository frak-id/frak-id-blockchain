// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { FrakAccessControlUpgradeable } from "./FrakAccessControlUpgradeable.sol";
import { NoReward, InvalidAddress, RewardTooLarge } from "./FrakErrors.sol";

/// @dev Error throwned when the contract havn't enough founds for the withdraw
error NotEnoughFound();

/**
 * @dev Abstraction for contract that give a push / pull reward, address based
 */
/// @custom:security-contact contact@frak.id
abstract contract PushPullReward is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * Access the token that will deliver the tokens
     */
    IERC20Upgradeable internal token;

    /**
     * The pending reward for the given address
     */
    mapping(address => uint256) internal _pendingRewards;

    /**
     * @notice Event emitted when a reward is added
     */
    event RewardAdded(address indexed user, uint256 amount);

    /**
     * @notice Event emitted when a user withdraw his pending reward
     */
    event RewardWithdrawed(address indexed user, uint256 amount, uint256 fees);

    /**
     * Init of this contract
     */
    function __PushPullReward_init(address tokenAddr) internal onlyInitializing {
        token = IERC20Upgradeable(tokenAddr);
    }

    /**
     * @dev Add founds for the given user
     */
    function _addFounds(address user, uint256 founds) internal {
        if (user == address(0)) revert InvalidAddress();
        emit RewardAdded(user, founds);
        _pendingRewards[user] += founds;
    }

    /**
     * @dev Add founds for the given user, without checking the operation (gas gain, usefull when founds are checked before)
     */
    function _addFoundsUnchecked(address user, uint256 founds) internal {
        emit RewardAdded(user, founds);
        unchecked {
            _pendingRewards[user] += founds;
        }
    }

    /**
     * @notice For a user to directly claim their founds
     */
    function withdrawFounds() external virtual;

    /**
     * @notice For an admin to withdraw the founds of the given user
     */
    function withdrawFounds(address user) external virtual;

    /**
     * @dev Core logic of the withdraw method
     */
    function _withdraw(address user) internal {
        if (user == address(0)) revert InvalidAddress();
        // Ensure the user have a pending reward
        uint256 pendingReward = _pendingRewards[user];
        if (pendingReward == 0) revert NoReward();
        // Reset the user pending balance
        _pendingRewards[user] = 0;
        // Emit the withdraw event
        emit RewardWithdrawed(user, pendingReward, 0);
        // Perform the transfer of the founds
        token.safeTransfer(user, pendingReward);
    }

    /**
     * @dev Core logic of the withdraw method, but with fee this time
     */
    function _withdrawWithFee(address user, uint256 feePercent, address feeRecipient) internal {
        if (user == address(0) || feeRecipient == address(0)) revert InvalidAddress();
        if (feePercent > 10) revert RewardTooLarge();
        // The fees can't be more than 10% of the user reward
        // Ensure the user have a pending reward
        uint256 pendingReward = _pendingRewards[user];
        if (pendingReward == 0) revert NoReward();
        // Reset the user pending balance
        _pendingRewards[user] = 0;
        // Compute the amount of fees
        uint256 feesAmount;
        uint256 userReward;
        unchecked {
            feesAmount = (pendingReward * feePercent) / 100;
            userReward = pendingReward - feesAmount;
        }
        // Emit the withdraw event
        emit RewardWithdrawed(user, userReward, feesAmount);
        // Perform the transfer of the founds
        token.safeTransfer(user, userReward);
        token.safeTransfer(feeRecipient, feesAmount);
    }

    /**
     * @notice Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint256) {
        if (user == address(0)) revert InvalidAddress();
        return _pendingRewards[user];
    }
}
