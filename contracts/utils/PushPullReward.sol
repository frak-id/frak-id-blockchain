// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {FrakAccessControlUpgradeable} from "./FrakAccessControlUpgradeable.sol";
import {NoReward, InvalidAddress, RewardTooLarge} from "./FrakErrors.sol";

/// @dev Error throwned when the contract havn't enough founds for the withdraw
error NotEnoughFound();

/**
 * @dev Abstraction for contract that give a push / pull reward, address based
 */
/// @custom:security-contact contact@frak.id
abstract contract PushPullReward is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("RewardTooLarge()")))'
    uint256 private constant _REWARD_TOO_LARGE_SELECTOR = 0x71009bf7;

    /// @dev 'bytes4(keccak256(bytes("NoReward()")))'
    uint256 private constant _NO_REWARD_SELECTOR = 0x6e992686;

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
        assembly {
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _addFoundsUnchecked(user, founds);
    }

    /**
     * @dev Add founds for the given user, without checking the operation (gas gain, usefull when founds are checked before)
     */
    function _addFoundsUnchecked(address user, uint256 founds) internal {
        emit RewardAdded(user, founds);
        assembly {
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            // Store the updated reward
            sstore(rewardSlot, add(sload(rewardSlot), founds))
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
        uint256 userAmount;
        assembly {
            // Check input params
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            userAmount := sload(rewardSlot)
            // Revert if no reward
            if iszero(userAmount) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Reset his reward
            sstore(rewardSlot, 0)
        }
        // Emit the withdraw event
        emit RewardWithdrawed(user, userAmount, 0);
        // Perform the transfer of the founds
        token.safeTransfer(user, userAmount);
    }

    /**
     * @dev Core logic of the withdraw method, but with fee this time
     */
    function _withdrawWithFee(address user, uint256 feePercent, address feeRecipient) internal {
        uint256 feesAmount;
        uint256 userAmount;
        assembly {
            // Check input params
            if or(iszero(user), iszero(feePercent)) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            if gt(feePercent, 10) {
                mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            let pendingReward := sload(rewardSlot)
            // Revert if no reward
            if iszero(pendingReward) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Reset his reward
            sstore(rewardSlot, 0)
            // Compute the fee's amount
            feesAmount := div(mul(pendingReward, feePercent), 100)
            userAmount := sub(pendingReward, feesAmount)
        }
        // Emit the withdraw event
        emit RewardWithdrawed(user, userAmount, feesAmount);
        // Perform the transfer of the founds
        token.safeTransfer(user, userAmount);
        token.safeTransfer(feeRecipient, feesAmount);
    }

    /**
     * @notice Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint256) {
        assembly {
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        return _pendingRewards[user];
    }
}
